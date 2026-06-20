#pragma once

#include <SDL3/SDL.h>

#include <filesystem>
#include <memory>
#include <string>
#include <unordered_map>

class FontRenderer {
public:
    void setFontsDirectory(std::filesystem::path path);
    void setScreenWidth(int width);

    double stringWidth(double height, const std::string& fontAlias, const std::string& text);
    int stringCursorIndex(double height, const std::string& fontAlias, const std::string& text, int curX, int curY);
    void drawString(
        SDL_Renderer* renderer,
        float x,
        float y,
        const std::string& align,
        double height,
        const std::string& fontAlias,
        const std::string& text,
        SDL_FColor color
    );

private:
    struct Impl;
    std::filesystem::path fontsDirectory;
    int screenWidth = 1600;
    std::unordered_map<std::string, std::shared_ptr<Impl>> cache;

    std::shared_ptr<Impl> getFont(const std::string& fontAlias);
    static std::string resolveFontName(const std::string& fontAlias);
};
