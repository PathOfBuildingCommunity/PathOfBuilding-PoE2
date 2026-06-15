#include "DdsDecode.hpp"

#define BCDEC_STATIC
#define BCDEC_IMPLEMENTATION
#include "bcdec.h"

#include <zstd.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

namespace {
constexpr uint32_t kDdsMagic = 0x20534444; // "DDS "
constexpr uint32_t kDdsHeaderSize = 124;
constexpr uint32_t kDx10FourCc = 0x30315844; // "DX10"
constexpr uint32_t kDxt1FourCc = 0x31545844; // "DXT1"

constexpr uint32_t kDxgiBc1Unorm = 71;
constexpr uint32_t kDxgiBc7Unorm = 98;
constexpr uint32_t kDxgiRgba8Unorm = 28;

enum class DdsFormat {
    Unknown,
    Bc1,
    Bc7,
    Rgba8,
};

struct DdsHeaderInfo {
    int cellWidth = 0;
    int cellHeight = 0;
    DdsFormat format = DdsFormat::Unknown;
    size_t dataOffset = 0;
    size_t dataSize = 0;
    int rowPitch = 0;
    int arraySize = 1; // DX10 texture-array slice count (PoE 0.5+ tree sheets)
};

uint32_t readU32(const std::vector<unsigned char>& data, size_t offset) {
    uint32_t value = 0;
    if (offset + 4 <= data.size()) {
        std::memcpy(&value, data.data() + offset, 4);
    }
    return value;
}

bool parseDdsHeader(const std::vector<unsigned char>& data, DdsHeaderInfo& info) {
    if (data.size() < 128 || readU32(data, 0) != kDdsMagic) {
        return false;
    }
    if (readU32(data, 4) != kDdsHeaderSize) {
        return false;
    }

    // DDS header: dwHeight at offset 12, dwWidth at offset 16.
    info.cellHeight = static_cast<int>(readU32(data, 12));
    info.cellWidth  = static_cast<int>(readU32(data, 16));
    const uint32_t linearSize = readU32(data, 20);
    const uint32_t fourCc = readU32(data, 84);

    info.dataOffset = 128;
    if (fourCc == kDx10FourCc) {
        if (data.size() < 148) {
            return false;
        }
        const uint32_t dxgiFormat = readU32(data, 128);
        info.dataOffset = 148;
        // DX10 extended header: arraySize is at offset 140.
        const uint32_t arraySize = readU32(data, 140);
        info.arraySize = arraySize > 0 ? static_cast<int>(arraySize) : 1;
        if (dxgiFormat == kDxgiBc1Unorm) {
            info.format = DdsFormat::Bc1;
        } else if (dxgiFormat == kDxgiBc7Unorm) {
            info.format = DdsFormat::Bc7;
        } else if (dxgiFormat == kDxgiRgba8Unorm) {
            info.format = DdsFormat::Rgba8;
            info.rowPitch = static_cast<int>(linearSize);
        } else {
            return false;
        }
    } else if (fourCc == kDxt1FourCc) {
        info.format = DdsFormat::Bc1;
    } else {
        const uint32_t rgbBitCount = readU32(data, 88);
        if (rgbBitCount == 32) {
            info.format = DdsFormat::Rgba8;
            info.rowPitch = static_cast<int>(linearSize);
        } else {
            return false;
        }
    }

    info.dataSize = data.size() - info.dataOffset;
    if (info.dataSize == 0 || info.cellWidth <= 0 || info.cellHeight <= 0) {
        return false;
    }
    if (info.format == DdsFormat::Rgba8 && info.rowPitch <= 0) {
        info.rowPitch = info.cellWidth * 4;
    }
    return true;
}

size_t compressedMipChainSize(int width, int height, DdsFormat format) {
    size_t total = 0;
    int w = width;
    int h = height;
    while (w >= 1 && h >= 1) {
        if (format == DdsFormat::Rgba8) {
            total += static_cast<size_t>(w) * h * 4;
        } else {
            const int blockBytes = format == DdsFormat::Bc7 ? 16 : 8;
            const int blocksX = std::max(1, (w + 3) / 4);
            const int blocksY = std::max(1, (h + 3) / 4);
            total += static_cast<size_t>(blocksX) * blocksY * blockBytes;
        }
        if (w == 1 && h == 1) {
            break;
        }
        w = std::max(1, w / 2);
        h = std::max(1, h / 2);
    }
    return total;
}

bool resolveAtlasDimensions(const DdsHeaderInfo& info, int& atlasWidth, int& atlasHeight) {
    atlasWidth = info.cellWidth;
    atlasHeight = info.cellHeight;

    const size_t tolerance = 4096;
    size_t bestDiff = static_cast<size_t>(-1);
    int bestWidth = info.cellWidth;
    int bestHeight = info.cellHeight;

    auto consider = [&](int width, int height) {
        if (width <= 0 || height <= 0) {
            return;
        }
        const size_t expected = compressedMipChainSize(width, height, info.format);
        const size_t diff = expected > info.dataSize ? expected - info.dataSize : info.dataSize - expected;
        if (diff < bestDiff) {
            bestDiff = diff;
            bestWidth = width;
            bestHeight = height;
        }
    };

    for (int cells = 1; cells <= 4096; ++cells) {
        consider(info.cellWidth, info.cellHeight * cells);
        consider(info.cellWidth * cells, info.cellHeight);
    }

    const int maxHeight = std::max(info.cellHeight * 4096, info.cellHeight + 16384);
    for (int height = info.cellHeight; height <= maxHeight; height += 4) {
        consider(info.cellWidth, height);
        const size_t expected = compressedMipChainSize(info.cellWidth, height, info.format);
        if (expected > info.dataSize + tolerance) {
            break;
        }
    }

    if (bestDiff > tolerance) {
        return false;
    }

    atlasWidth = bestWidth;
    atlasHeight = bestHeight;
    return true;
}

size_t mip0CompressedSize(int width, int height, DdsFormat format) {
    if (format == DdsFormat::Rgba8) {
        return static_cast<size_t>(width) * height * 4;
    }
    const int blockBytes = format == DdsFormat::Bc7 ? 16 : 8;
    const int blocksX = std::max(1, (width + 3) / 4);
    const int blocksY = std::max(1, (height + 3) / 4);
    return static_cast<size_t>(blocksX) * blocksY * blockBytes;
}

void decodeBc1Region(
    const unsigned char* src,
    int atlasWidth,
    int atlasHeight,
    std::vector<unsigned char>& rgba
) {
    const int blocksX = std::max(1, (atlasWidth + 3) / 4);
    const int blocksY = std::max(1, (atlasHeight + 3) / 4);
    unsigned char blockRgba[4 * 4 * 4];

    for (int by = 0; by < blocksY; ++by) {
        for (int bx = 0; bx < blocksX; ++bx) {
            bcdec_bc1(src + (static_cast<size_t>(by) * blocksX + bx) * 8, blockRgba, 16);
            for (int py = 0; py < 4; ++py) {
                for (int px = 0; px < 4; ++px) {
                    const int x = bx * 4 + px;
                    const int y = by * 4 + py;
                    if (x >= atlasWidth || y >= atlasHeight) {
                        continue;
                    }
                    const size_t dst = (static_cast<size_t>(y) * atlasWidth + x) * 4;
                    const size_t srcPx = (static_cast<size_t>(py) * 4 + px) * 4;
                    rgba[dst + 0] = blockRgba[srcPx + 0];
                    rgba[dst + 1] = blockRgba[srcPx + 1];
                    rgba[dst + 2] = blockRgba[srcPx + 2];
                    rgba[dst + 3] = blockRgba[srcPx + 3];
                }
            }
        }
    }
}

void decodeBc7Region(
    const unsigned char* src,
    int atlasWidth,
    int atlasHeight,
    std::vector<unsigned char>& rgba
) {
    const int blocksX = std::max(1, (atlasWidth + 3) / 4);
    const int blocksY = std::max(1, (atlasHeight + 3) / 4);
    unsigned char blockRgba[4 * 4 * 4];

    for (int by = 0; by < blocksY; ++by) {
        for (int bx = 0; bx < blocksX; ++bx) {
            bcdec_bc7(src + (static_cast<size_t>(by) * blocksX + bx) * 16, blockRgba, 16);
            for (int py = 0; py < 4; ++py) {
                for (int px = 0; px < 4; ++px) {
                    const int x = bx * 4 + px;
                    const int y = by * 4 + py;
                    if (x >= atlasWidth || y >= atlasHeight) {
                        continue;
                    }
                    const size_t dst = (static_cast<size_t>(y) * atlasWidth + x) * 4;
                    const size_t srcPx = (static_cast<size_t>(py) * 4 + px) * 4;
                    rgba[dst + 0] = blockRgba[srcPx + 0];
                    rgba[dst + 1] = blockRgba[srcPx + 1];
                    rgba[dst + 2] = blockRgba[srcPx + 2];
                    rgba[dst + 3] = blockRgba[srcPx + 3];
                }
            }
        }
    }
}

void decodeRgba8Region(
    const unsigned char* src,
    int atlasWidth,
    int atlasHeight,
    int rowPitch,
    std::vector<unsigned char>& rgba
) {
    for (int y = 0; y < atlasHeight; ++y) {
        const unsigned char* row = src + static_cast<size_t>(y) * rowPitch;
        for (int x = 0; x < atlasWidth; ++x) {
            const size_t dst = (static_cast<size_t>(y) * atlasWidth + x) * 4;
            const size_t srcPx = static_cast<size_t>(x) * 4;
            rgba[dst + 0] = row[srcPx + 0];
            rgba[dst + 1] = row[srcPx + 1];
            rgba[dst + 2] = row[srcPx + 2];
            rgba[dst + 3] = row[srcPx + 3];
        }
    }
}
}

bool zstdDecompressBytes(const std::vector<unsigned char>& input, std::vector<unsigned char>& output) {
    if (input.empty()) {
        return false;
    }
    const unsigned long long size = ZSTD_getFrameContentSize(input.data(), input.size());
    if (size == ZSTD_CONTENTSIZE_ERROR || size == ZSTD_CONTENTSIZE_UNKNOWN) {
        return false;
    }
    output.resize(static_cast<size_t>(size));
    const size_t result = ZSTD_decompress(output.data(), output.size(), input.data(), input.size());
    if (ZSTD_isError(result) || result != output.size()) {
        output.clear();
        return false;
    }
    return true;
}

bool decodeDdsBytes(const std::vector<unsigned char>& ddsData, DecodedDds& out) {
    DdsHeaderInfo info;
    if (!parseDdsHeader(ddsData, info)) {
        return false;
    }

    // PoE 0.5+ tree sprite sheets ship as DX10 texture arrays: each array slice
    // is one cell (cellWidth x cellHeight) stored as its own full mip chain. The
    // Lua tree code addresses cells by 1-based array index. We flatten the array
    // into a single atlas the host can sample by index. A pure vertical strip
    // (cellHeight * arraySize) would exceed the GPU max texture size for large
    // arrays, so lay the cells out in a grid; the host's index->rect math derives
    // the column count from atlasWidth / cellWidth and stays consistent.
    if (info.arraySize > 1) {
        const int cellW = info.cellWidth;
        const int cellH = info.cellHeight;
        const size_t sliceMip0 = mip0CompressedSize(cellW, cellH, info.format);
        const size_t sliceChain = compressedMipChainSize(cellW, cellH, info.format);
        if (cellW <= 0 || cellH <= 0 || sliceMip0 == 0 || sliceChain < sliceMip0) {
            return false;
        }
        // Last slice only needs its mip0 present, not its trailing mips.
        const size_t required = sliceChain * (static_cast<size_t>(info.arraySize) - 1) + sliceMip0;
        if (info.dataSize < required) {
            return false;
        }

        // Choose a grid that keeps both atlas dimensions within the GPU limit.
        constexpr int kMaxDim = 16383; // stay strictly under Metal's max texture size
        const int maxCols = std::max(1, kMaxDim / cellW);
        const int maxRows = std::max(1, kMaxDim / cellH);
        int cols = std::min(maxCols, info.arraySize);
        int rows = (info.arraySize + cols - 1) / cols;
        if (rows > maxRows) {
            rows = maxRows;
            cols = (info.arraySize + rows - 1) / rows;
        }
        if (cols > maxCols || static_cast<long long>(cols) * rows < info.arraySize) {
            return false; // array too large to fit in one atlas texture
        }

        const int atlasW = cols * cellW;
        const int atlasH = rows * cellH;
        const unsigned char* base = ddsData.data() + info.dataOffset;

        out.rgba.assign(static_cast<size_t>(atlasW) * atlasH * 4, 0);
        out.cellWidth = cellW;
        out.cellHeight = cellH;
        out.atlasWidth = atlasW;
        out.atlasHeight = atlasH;
        out.stackedAtlas = true;

        std::vector<unsigned char> cell(static_cast<size_t>(cellW) * cellH * 4, 0);
        for (int i = 0; i < info.arraySize; ++i) {
            const unsigned char* sliceMip0Ptr = base + static_cast<size_t>(i) * sliceChain;
            std::fill(cell.begin(), cell.end(), static_cast<unsigned char>(0));
            if (info.format == DdsFormat::Bc1) {
                decodeBc1Region(sliceMip0Ptr, cellW, cellH, cell);
            } else if (info.format == DdsFormat::Bc7) {
                decodeBc7Region(sliceMip0Ptr, cellW, cellH, cell);
            } else {
                // Rgba8: raw RGBA pixels, rowPitch may include padding
                const int rowPitch = info.rowPitch > 0 ? info.rowPitch : cellW * 4;
                decodeRgba8Region(sliceMip0Ptr, cellW, cellH, rowPitch, cell);
            }
            const int col = i % cols;
            const int row = i / cols;
            const int dstX = col * cellW;
            const int dstY = row * cellH;
            for (int y = 0; y < cellH; ++y) {
                std::memcpy(
                    out.rgba.data() + (static_cast<size_t>(dstY + y) * atlasW + dstX) * 4,
                    cell.data() + static_cast<size_t>(y) * cellW * 4,
                    static_cast<size_t>(cellW) * 4);
            }
        }
        return true;
    }

    int atlasWidth = 0;
    int atlasHeight = 0;
    if (!resolveAtlasDimensions(info, atlasWidth, atlasHeight)) {
        return false;
    }

    const size_t mip0Size = mip0CompressedSize(atlasWidth, atlasHeight, info.format);
    if (info.dataSize < mip0Size) {
        return false;
    }

    const unsigned char* mip0 = ddsData.data() + info.dataOffset;
    out.rgba.assign(static_cast<size_t>(atlasWidth) * atlasHeight * 4, 0);
    out.cellWidth = info.cellWidth;
    out.cellHeight = info.cellHeight;
    out.atlasWidth = atlasWidth;
    out.atlasHeight = atlasHeight;
    out.stackedAtlas = atlasHeight > info.cellHeight || atlasWidth > info.cellWidth;

    switch (info.format) {
        case DdsFormat::Bc1:
            decodeBc1Region(mip0, atlasWidth, atlasHeight, out.rgba);
            break;
        case DdsFormat::Bc7:
            decodeBc7Region(mip0, atlasWidth, atlasHeight, out.rgba);
            break;
        case DdsFormat::Rgba8:
            decodeRgba8Region(mip0, atlasWidth, atlasHeight, info.rowPitch, out.rgba);
            break;
        default:
            return false;
    }
    return true;
}
