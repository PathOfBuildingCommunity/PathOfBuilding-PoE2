#pragma once

#include <cstddef>
#include <vector>

struct DecodedDds {
    int cellWidth = 0;
    int cellHeight = 0;
    int atlasWidth = 0;
    int atlasHeight = 0;
    bool stackedAtlas = false;
    std::vector<unsigned char> rgba;
};

bool zstdDecompressBytes(const std::vector<unsigned char>& input, std::vector<unsigned char>& output);
bool decodeDdsBytes(const std::vector<unsigned char>& ddsData, DecodedDds& out);
