#include "TgaImage.hpp"

#include <algorithm>
#include <fstream>
#include <iterator>
#include <vector>

namespace {
std::vector<unsigned char> readFileBytes(const std::filesystem::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        return {};
    }
    return std::vector<unsigned char>(std::istreambuf_iterator<char>(input), {});
}
}

bool decodeTgaPixels(const std::vector<unsigned char>& data, int& width, int& height, std::vector<unsigned char>& rgba) {
    if (data.size() < 18) {
        return false;
    }
    const unsigned char idLength = data[0];
    const unsigned char imageType = data[2];
    width = data[12] | (data[13] << 8);
    height = data[14] | (data[15] << 8);
    const unsigned char bpp = data[16];
    const unsigned char descriptor = data[17];
    if (width <= 0 || height <= 0 || (imageType != 2 && imageType != 10) || (bpp != 24 && bpp != 32)) {
        return false;
    }

    const size_t pixelBytes = bpp / 8;
    size_t offset = 18 + idLength;
    rgba.assign(static_cast<size_t>(width) * height * 4, 0);
    int pixelIndex = 0;
    const int pixelCount = width * height;

    auto writePixel = [&](const unsigned char* src) {
        int x = pixelIndex % width;
        int y = pixelIndex / width;
        if ((descriptor & 0x20) == 0) {
            y = height - 1 - y;
        }
        size_t out = (static_cast<size_t>(y) * width + x) * 4;
        rgba[out + 0] = src[2];
        rgba[out + 1] = src[1];
        rgba[out + 2] = src[0];
        rgba[out + 3] = pixelBytes == 4 ? src[3] : 255;
        pixelIndex++;
    };

    if (imageType == 2) {
        while (pixelIndex < pixelCount && offset + pixelBytes <= data.size()) {
            writePixel(&data[offset]);
            offset += pixelBytes;
        }
    } else {
        while (pixelIndex < pixelCount && offset < data.size()) {
            unsigned char header = data[offset++];
            int count = (header & 0x7f) + 1;
            if (header & 0x80) {
                if (offset + pixelBytes > data.size()) {
                    return false;
                }
                for (int i = 0; i < count && pixelIndex < pixelCount; ++i) {
                    writePixel(&data[offset]);
                }
                offset += pixelBytes;
            } else {
                for (int i = 0; i < count && pixelIndex < pixelCount; ++i) {
                    if (offset + pixelBytes > data.size()) {
                        return false;
                    }
                    writePixel(&data[offset]);
                    offset += pixelBytes;
                }
            }
        }
    }
    return pixelIndex == pixelCount;
}

SDL_Texture* loadTgaTexture(SDL_Renderer* renderer, const std::filesystem::path& path, int& width, int& height) {
    auto data = readFileBytes(path);
    std::vector<unsigned char> rgba;
    if (!decodeTgaPixels(data, width, height, rgba)) {
        return nullptr;
    }
    SDL_Surface* surface = SDL_CreateSurfaceFrom(
        width,
        height,
        SDL_PIXELFORMAT_RGBA32,
        rgba.data(),
        width * 4
    );
    if (!surface) {
        return nullptr;
    }
    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_DestroySurface(surface);
    if (texture) {
        SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
    }
    return texture;
}
