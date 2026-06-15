#include "FontRenderer.hpp"
#include "TgaImage.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <memory>
#include <vector>

namespace {
struct Glyph {
    float tcLeft = 0.0f;
    float tcRight = 0.0f;
    float tcTop = 0.0f;
    float tcBottom = 0.0f;
    int pixelX = 0;
    int pixelY = 0;
    int width = 0;
    int spLeft = 0;
    int spRight = 0;
};

struct FontHeight {
    std::filesystem::path tgaPath;
    SDL_Texture* texture = nullptr;
    int atlasWidth = 0;
    int atlasHeight = 0;
    int height = 0;
    int numGlyph = 0;
    std::array<Glyph, 128> glyphs{};
    Glyph defGlyph{};

    const Glyph& glyph(unsigned char ch) const {
        if (ch >= static_cast<unsigned char>(numGlyph)) {
            return defGlyph;
        }
        return glyphs[ch];
    }

    ~FontHeight() {
        if (texture) {
            SDL_DestroyTexture(texture);
        }
    }

    bool ensureTexture(SDL_Renderer* renderer) {
        if (texture || tgaPath.empty()) {
            return texture != nullptr;
        }
        texture = loadTgaTexture(renderer, tgaPath, atlasWidth, atlasHeight);
        if (!texture || atlasWidth <= 0 || atlasHeight <= 0) {
            return false;
        }
        for (int i = 0; i < numGlyph; ++i) {
            Glyph& glyph = glyphs[i];
            glyph.tcLeft = static_cast<float>(glyph.pixelX) / atlasWidth;
            glyph.tcRight = static_cast<float>(glyph.pixelX + glyph.width) / atlasWidth;
            glyph.tcTop = static_cast<float>(glyph.pixelY) / atlasHeight;
            glyph.tcBottom = static_cast<float>(glyph.pixelY + height) / atlasHeight;
        }
        return true;
    }
};

struct FontImpl {
    std::string name;
    std::vector<std::unique_ptr<FontHeight>> heights;
    std::vector<int> heightMap;
    int maxHeight = 0;

    bool load(const std::filesystem::path& fontsDir, const std::string& fontName) {
        name = fontName;
        const std::filesystem::path tgfPath = fontsDir / (fontName + ".tgf");
        std::ifstream tgf(tgfPath);
        if (!tgf) {
            std::fprintf(stderr, "Font metadata not found: %s\n", tgfPath.string().c_str());
            return false;
        }

        FontHeight* current = nullptr;
        std::string line;
        while (std::getline(tgf, line)) {
            unsigned h = 0;
            unsigned x = 0;
            unsigned y = 0;
            unsigned w = 0;
            int sl = 0;
            int sr = 0;
            if (std::sscanf(line.c_str(), "HEIGHT %u;", &h) == 1) {
                auto fh = std::make_unique<FontHeight>();
                fh->height = static_cast<int>(h);
                fh->tgaPath = fontsDir / (fontName + "." + std::to_string(h) + ".tga");
                maxHeight = std::max(maxHeight, fh->height);
                current = fh.get();
                heights.push_back(std::move(fh));
            } else if (current && std::sscanf(line.c_str(), "GLYPH %u %u %u %d %d;", &x, &y, &w, &sl, &sr) == 5) {
                if (current->numGlyph >= 128) {
                    continue;
                }
                Glyph& glyph = current->glyphs[current->numGlyph++];
                glyph.pixelX = static_cast<int>(x);
                glyph.pixelY = static_cast<int>(y);
                glyph.width = static_cast<int>(w);
                glyph.spLeft = sl;
                glyph.spRight = sr;
            }
        }

        if (heights.empty()) {
            return false;
        }

        heightMap.assign(static_cast<size_t>(maxHeight) + 1, 0);
        for (size_t i = 0; i < heights.size(); ++i) {
            const int gh = heights[i]->height;
            for (int h = gh; h <= maxHeight; ++h) {
                heightMap[static_cast<size_t>(h)] = static_cast<int>(i);
            }
            if (i > 0) {
                const int belowH = heights[i - 1]->height;
                const int lim = (gh - belowH - 1) / 2;
                for (int b = 0; b < lim; ++b) {
                    heightMap[static_cast<size_t>(gh - b - 1)] = static_cast<int>(i);
                }
            }
        }
        return true;
    }

    bool ensureTextures(SDL_Renderer* renderer) {
        bool ok = true;
        for (auto& entry : heights) {
            if (!entry->ensureTexture(renderer)) {
                std::fprintf(stderr, "Font atlas not found: %s\n", entry->tgaPath.string().c_str());
                ok = false;
            }
        }
        return ok;
    }

    FontHeight* findFontHeight(int height) const {
        if (heights.empty()) {
            return nullptr;
        }
        int idx = 0;
        if (height > maxHeight) {
            idx = static_cast<int>(heights.size()) - 1;
        } else if (height < 0) {
            idx = 0;
        } else {
            idx = heightMap[static_cast<size_t>(height)];
        }
        return heights[static_cast<size_t>(idx)].get();
    }

    int heightIndex(const FontHeight* fh) const {
        for (size_t i = 0; i < heights.size(); ++i) {
            if (heights[i].get() == fh) {
                return static_cast<int>(i);
            }
        }
        return 0;
    }

    FontHeight* findSmallerFontHeight(int height, int heightIdx, int sizeReduction) const {
        FontHeight* result = heights[static_cast<size_t>(heightIdx)].get();
        for (int idx = heightIdx - 1; idx >= 0; --idx) {
            FontHeight* candidate = heights[static_cast<size_t>(idx)].get();
            if (height - candidate->height >= sizeReduction) {
                return candidate;
            }
        }
        return result;
    }

    int glyphAdvance(const FontHeight* fh, unsigned char ch) const {
        const Glyph& g = fh->glyph(ch);
        return g.width + g.spLeft + g.spRight;
    }

    int stringWidthInternal(const FontHeight* fh, const std::string& text, int height, float scale) const {
        const int heightIdx = heightIndex(fh);
        const FontHeight* tofuFont = findSmallerFontHeight(height, heightIdx, 3);

        float width = 0.0f;
        for (size_t i = 0; i < text.size();) {
            if (text[i] == '^') {
                if (i + 1 < text.size() && text[i + 1] >= '0' && text[i + 1] <= '9') {
                    i += 2;
                    continue;
                }
                if (i + 7 < text.size() && text[i + 1] == 'x') {
                    i += 8;
                    continue;
                }
            }
            if (text[i] == '\n') {
                break;
            }
            if (text[i] == '\t') {
                width += glyphAdvance(fh, ' ') * 4.0f * scale;
                width = std::ceil(width);
                ++i;
                continue;
            }
            const unsigned char ch = static_cast<unsigned char>(text[i]);
            if (ch >= static_cast<unsigned char>(fh->numGlyph)) {
                width += glyphAdvance(tofuFont, '?') * scale;
            } else {
                width += glyphAdvance(fh, ch) * scale;
            }
            width = std::ceil(width);
            ++i;
        }
        return static_cast<int>(width);
    }

    int stringWidth(int height, const std::string& text) const {
        FontHeight* fh = findFontHeight(height);
        if (!fh) {
            return 0;
        }
        const float scale = static_cast<float>(height) / fh->height;
        int maxWidth = 0;
        size_t start = 0;
        while (start <= text.size()) {
            size_t end = text.find('\n', start);
            if (end == std::string::npos) {
                end = text.size();
            }
            if (end > start) {
                maxWidth = std::max(maxWidth, stringWidthInternal(fh, text.substr(start, end - start), height, scale));
            }
            if (end == text.size()) {
                break;
            }
            start = end + 1;
        }
        return maxWidth;
    }

    size_t stringCursorInternal(const FontHeight* fh, const std::string& text, int height, float scale, int curX) const {
        const int heightIdx = heightIndex(fh);
        const FontHeight* tofuFont = findSmallerFontHeight(height, heightIdx, 3);

        float x = 0.0f;
        size_t i = 0;
        while (i < text.size() && text[i] != '\n') {
            if (text[i] == '^') {
                if (i + 1 < text.size() && text[i + 1] >= '0' && text[i + 1] <= '9') {
                    i += 2;
                    continue;
                }
                if (i + 7 < text.size() && text[i + 1] == 'x') {
                    i += 8;
                    continue;
                }
            }
            if (text[i] == '\t') {
                const float fullWidth = glyphAdvance(fh, ' ') * 4.0f * scale;
                const float halfWidth = std::ceil(fullWidth / 2.0f);
                x += halfWidth;
                x = std::ceil(x);
                if (curX <= x) {
                    break;
                }
                x += fullWidth - halfWidth;
                x = std::ceil(x);
                if (curX <= x) {
                    break;
                }
                ++i;
                continue;
            }
            const unsigned char ch = static_cast<unsigned char>(text[i]);
            if (ch >= static_cast<unsigned char>(fh->numGlyph)) {
                x += glyphAdvance(tofuFont, '?') * scale;
            } else {
                x += glyphAdvance(fh, ch) * scale;
            }
            x = std::ceil(x);
            if (curX <= x) {
                break;
            }
            ++i;
        }
        return i;
    }

    int stringCursorIndex(int height, const std::string& text, int curX, int curY) const {
        FontHeight* fh = findFontHeight(height);
        if (!fh) {
            return 0;
        }
        const float scale = static_cast<float>(height) / fh->height;
        size_t index = 0;
        int lineY = height;
        size_t start = 0;
        while (start <= text.size()) {
            size_t end = text.find('\n', start);
            if (end == std::string::npos) {
                end = text.size();
            }
            const size_t local = stringCursorInternal(fh, text.substr(start, end - start), height, scale, curX);
            index = start + local;
            if (curY <= lineY) {
                break;
            }
            if (end == text.size()) {
                break;
            }
            start = end + 1;
            lineY += height;
        }
        return static_cast<int>(index);
    }

    void drawCodepoint(
        SDL_Renderer* renderer,
        FontHeight*& currentTexture,
        float& x,
        float y,
        const FontHeight* fh,
        int drawHeight,
        float scale,
        int yShift,
        unsigned char ch,
        SDL_FColor color
    ) const {
        const float cpY = y + static_cast<float>(yShift);
        if (currentTexture != fh) {
            currentTexture = const_cast<FontHeight*>(fh);
        }
        const Glyph& glyph = fh->glyph(ch);
        x += glyph.spLeft * scale;
        if (glyph.width > 0) {
            const float w = glyph.width * scale;
            SDL_FRect dest{x, cpY, w, static_cast<float>(drawHeight)};
            SDL_FRect src{
                glyph.tcLeft * fh->atlasWidth,
                glyph.tcTop * fh->atlasHeight,
                (glyph.tcRight - glyph.tcLeft) * fh->atlasWidth,
                (glyph.tcBottom - glyph.tcTop) * fh->atlasHeight,
            };
            SDL_SetTextureColorModFloat(fh->texture, color.r, color.g, color.b);
            SDL_SetTextureAlphaModFloat(fh->texture, color.a);
            SDL_RenderTexture(renderer, fh->texture, &src, &dest);
            x += w;
        }
        x += glyph.spRight * scale;
        x = std::ceil(x);
    }

    void drawTextLine(
        SDL_Renderer* renderer,
        float x,
        float y,
        const std::string& align,
        int height,
        const std::string& text,
        SDL_FColor color,
        int screenWidth
    ) const {
        FontHeight* fh = findFontHeight(height);
        if (!fh || !fh->texture) {
            return;
        }
        const float scale = static_cast<float>(height) / fh->height;
        const int heightIdx = heightIndex(fh);
        const FontHeight* tofuFont = findSmallerFontHeight(height, heightIdx, 3);
        const int tofuPad = (tofuFont != fh) ? static_cast<int>(std::ceil((height - tofuFont->height) / 2.0f)) : 0;

        if (align == "CENTER") {
            x = std::floor((screenWidth - stringWidthInternal(fh, text, height, scale)) / 2.0f + x);
        } else if (align == "RIGHT") {
            x = std::floor(screenWidth - stringWidthInternal(fh, text, height, scale) - x);
        } else if (align == "CENTER_X") {
            x = std::floor(x - stringWidthInternal(fh, text, height, scale) / 2.0f);
        } else if (align == "RIGHT_X") {
            x = std::floor(x - stringWidthInternal(fh, text, height, scale));
        }
        x = std::round(x);

        FontHeight* currentTexture = nullptr;
        for (size_t i = 0; i < text.size();) {
            if (text[i] == '^') {
                if (i + 1 < text.size() && text[i + 1] >= '0' && text[i + 1] <= '9') {
                    i += 2;
                    continue;
                }
                if (i + 7 < text.size() && text[i + 1] == 'x') {
                    i += 8;
                    continue;
                }
            }
            if (text[i] == '\t') {
                x += glyphAdvance(fh, ' ') * 4.0f * scale;
                ++i;
                continue;
            }
            const unsigned char ch = static_cast<unsigned char>(text[i]);
            if (ch >= static_cast<unsigned char>(fh->numGlyph)) {
                drawCodepoint(renderer, currentTexture, x, y, tofuFont, tofuFont->height, 1.0f, tofuPad, '?', color);
            } else {
                drawCodepoint(renderer, currentTexture, x, y, fh, height, scale, 0, ch, color);
            }
            ++i;
        }
    }

    void drawString(
        SDL_Renderer* renderer,
        float x,
        float y,
        const std::string& align,
        int height,
        const std::string& text,
        SDL_FColor color,
        int screenWidth
    ) const {
        if (text.empty()) {
            return;
        }
        size_t start = 0;
        float lineY = y;
        while (start <= text.size()) {
            size_t end = text.find('\n', start);
            if (end == std::string::npos) {
                end = text.size();
            }
            if (end > start) {
                drawTextLine(renderer, x, lineY, align, height, text.substr(start, end - start), color, screenWidth);
            }
            lineY += height;
            if (end == text.size()) {
                break;
            }
            start = end + 1;
        }
    }
};
}

struct FontRenderer::Impl : FontImpl {};

void FontRenderer::setFontsDirectory(std::filesystem::path path) {
    fontsDirectory = std::move(path);
    cache.clear();
}

void FontRenderer::setScreenWidth(int width) {
    screenWidth = width;
}

std::string FontRenderer::resolveFontName(const std::string& fontAlias) {
    if (fontAlias == "FIXED") {
        return "Bitstream Vera Sans Mono";
    }
    if (fontAlias == "VAR BOLD") {
        return "Liberation Sans Bold";
    }
    if (fontAlias == "VAR") {
        return "Liberation Sans";
    }
    if (fontAlias == "FONTIN SC ITALIC") {
        return "Fontin SmallCaps Italic";
    }
    if (fontAlias == "FONTIN SC") {
        return "Fontin SmallCaps";
    }
    if (fontAlias == "FONTIN ITALIC") {
        return "Fontin Italic";
    }
    if (fontAlias == "FONTIN") {
        return "Fontin";
    }
    return fontAlias;
}

std::shared_ptr<FontRenderer::Impl> FontRenderer::getFont(const std::string& fontAlias) {
    const auto it = cache.find(fontAlias);
    if (it != cache.end()) {
        return it->second;
    }
    auto font = std::make_shared<Impl>();
    if (!font->load(fontsDirectory, resolveFontName(fontAlias))) {
        return nullptr;
    }
    cache.emplace(fontAlias, font);
    return font;
}

double FontRenderer::stringWidth(double height, const std::string& fontAlias, const std::string& text) {
    auto font = getFont(fontAlias);
    if (!font) {
        return 0.0;
    }
    return font->stringWidth(static_cast<int>(std::lround(height)), text);
}

int FontRenderer::stringCursorIndex(double height, const std::string& fontAlias, const std::string& text, int curX, int curY) {
    auto font = getFont(fontAlias);
    if (!font) {
        return 0;
    }
    return font->stringCursorIndex(static_cast<int>(std::lround(height)), text, curX, curY);
}

void FontRenderer::drawString(
    SDL_Renderer* renderer,
    float x,
    float y,
    const std::string& align,
    double height,
    const std::string& fontAlias,
    const std::string& text,
    SDL_FColor color
) {
    auto font = getFont(fontAlias);
    if (!font || !renderer) {
        return;
    }
    font->ensureTextures(renderer);
    font->drawString(renderer, x, y, align, static_cast<int>(std::lround(height)), text, color, screenWidth);
}
