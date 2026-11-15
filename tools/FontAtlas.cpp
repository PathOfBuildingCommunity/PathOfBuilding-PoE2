// 使用指定字体生成透明字形图集，供官方 SimpleGraphic 的图像接口直接绘制。
#define NOMINMAX
#include <windows.h>
#include <filesystem>
#include <fstream>
#include <vector>
#include <iostream>
#include <algorithm>

namespace fs = std::filesystem;
namespace {
constexpr int size = 2048, cell = 36, pixels = 32;

// 写入带透明通道的无损 RLE TGA，避免为大面积透明区域保存重复像素。
void SavePage(const fs::path& folder, int page, const std::vector<unsigned char>& rgba) {
    wchar_t name[32]; swprintf_s(name, L"atlas-%02d.tga", page);
    std::ofstream out(folder / name, std::ios::binary);
    unsigned char header[18] = {0, 0, 10};
    header[12] = size & 255; header[13] = size >> 8;
    header[14] = size & 255; header[15] = size >> 8;
    header[16] = 32; header[17] = 0x28;
    out.write(reinterpret_cast<char*>(header), 18);
    for (size_t i = 0; i < rgba.size() / 4;) {
        size_t count = 1;
        while (count < 128 && count < size - i % size && i + count < rgba.size() / 4 &&
            std::equal(rgba.data() + i * 4, rgba.data() + i * 4 + 4, rgba.data() + (i + count) * 4)) ++count;
        out.put(static_cast<char>(0x80 | (count - 1)));
        out.write(reinterpret_cast<const char*>(rgba.data() + i * 4), 4);
        i += count;
    }
    if (!out) throw std::runtime_error("Unable to write font atlas");
}
}

/// <summary>从指定字体生成字形、布局指标和图集文件。</summary>
int wmain(int argc, wchar_t** argv) {
    if (argc < 2 || argc > 4) { std::cerr << "Usage: FontAtlas <output-folder> [font-face] [font-file]\n"; return 1; }
    try {
        fs::path folder(argv[1]); fs::create_directories(folder);
        // 清理上一次生成后多余的图集页，避免旧字体页面混入发布包。
        for (const auto& entry : fs::directory_iterator(folder)) {
            if (entry.path().extension() == L".tga" && entry.path().filename().wstring().rfind(L"atlas-", 0) == 0) {
                fs::remove(entry.path());
            }
        }
        bool privateFont = false;
        if (argc == 4) {
            fs::path fontPath(argv[3]);
            if (!fs::exists(fontPath) || !AddFontResourceExW(fontPath.c_str(), FR_PRIVATE, nullptr)) {
                throw std::runtime_error("Unable to load font file");
            }
            privateFont = true;
        }
        const wchar_t* face = argc >= 3 ? argv[2] : L"Noto Sans SC";
        HDC dc = CreateCompatibleDC(nullptr);
        HFONT font = CreateFontW(-pixels, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
            DEFAULT_PITCH, face);
        if (!dc || !font) throw std::runtime_error("Unable to create system font");
        auto previous = SelectObject(dc, font);
        wchar_t actualFace[LF_FACESIZE]{};
        if (!GetTextFaceW(dc, LF_FACESIZE, actualFace) || wcscmp(actualFace, face) != 0) {
            throw std::runtime_error("Requested font face is not available");
        }
        std::ofstream metrics(folder / "Glyphs.lua", std::ios::binary);
		metrics << "-- 字体图集生成；重新运行 build.cmd 可重建。\nreturn { size=32, baseline=29, atlasSize=2048, glyphs={\n";
        std::vector<unsigned char> atlas(size * size * 4, 0);
        MAT2 matrix = {{0,1},{0,0},{0,0},{0,1}};
        int page = 1, slot = 0, count = 0;
        constexpr int columns = size / cell;
        for (unsigned cp = 32; cp < 65536; ++cp) {
            if (cp >= 0xd800 && cp <= 0xdfff) continue;
            wchar_t ch = static_cast<wchar_t>(cp); WORD glyph;
            if (GetGlyphIndicesW(dc, &ch, 1, &glyph, GGI_MARK_NONEXISTING_GLYPHS) == GDI_ERROR || glyph == 0xffff) continue;
            GLYPHMETRICS gm{};
            DWORD bytes = GetGlyphOutlineW(dc, cp, GGO_GRAY8_BITMAP, &gm, 0, nullptr, &matrix);
            if (bytes == GDI_ERROR || gm.gmBlackBoxX > cell || gm.gmBlackBoxY > cell) continue;
            if (slot == columns * columns) {
                SavePage(folder, page++, atlas); std::fill(atlas.begin(), atlas.end(), 0); slot = 0;
            }
            int x = (slot % columns) * cell, y = (slot / columns) * cell;
            if (bytes) {
                std::vector<unsigned char> bitmap(bytes);
                if (GetGlyphOutlineW(dc, cp, GGO_GRAY8_BITMAP, &gm, bytes, bitmap.data(), &matrix) == GDI_ERROR) continue;
                int stride = (gm.gmBlackBoxX + 3) & ~3;
                for (unsigned row = 0; row < gm.gmBlackBoxY; ++row) {
                    for (unsigned col = 0; col < gm.gmBlackBoxX; ++col) {
                        size_t dst = ((y + row) * size + x + col) * 4;
                        atlas[dst] = atlas[dst+1] = atlas[dst+2] = 255;
                        atlas[dst+3] = static_cast<unsigned char>(std::min(255, bitmap[row * stride + col] * 255 / 64));
                    }
                }
            }
            metrics << '[' << cp << "]={" << page << ',' << x << ',' << y << ',' << gm.gmBlackBoxX << ','
                << gm.gmBlackBoxY << ',' << gm.gmptGlyphOrigin.x << ',' << gm.gmptGlyphOrigin.y << ',' << gm.gmCellIncX << "},\n";
            ++slot; ++count;
        }
        SavePage(folder, page, atlas); metrics << "}}\n"; metrics.close();
        SelectObject(dc, previous); DeleteObject(font); DeleteDC(dc);
        if (privateFont) RemoveFontResourceExW(argv[3], FR_PRIVATE, nullptr);
        if (!metrics) throw std::runtime_error("Unable to write font metrics");
        std::cout << "Generated " << count << " glyphs in " << page << " pages.\n";
        return 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
