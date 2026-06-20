#pragma once

#include <SDL3/SDL.h>

#include <filesystem>
#include <vector>

bool decodeTgaPixels(const std::vector<unsigned char>& data, int& width, int& height, std::vector<unsigned char>& rgba);
SDL_Texture* loadTgaTexture(SDL_Renderer* renderer, const std::filesystem::path& path, int& width, int& height);
