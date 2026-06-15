#include "Host.hpp"
#include "DdsDecode.hpp"

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <curl/curl.h>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <cstdarg>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string>
#include <vector>
#include <unistd.h>
#include <zlib.h>
#include <cerrno>
#include <cstring>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/select.h>

namespace fs = std::filesystem;

namespace {
constexpr const char* kMainObject = "__pob_main_object";
constexpr const char* kCallbacks = "__pob_callbacks";
constexpr const char* kScriptPath = "__pob_script_path";
constexpr const char* kRuntimePath = "__pob_runtime_path";

auto startTime = std::chrono::steady_clock::now();

struct NativeImage {
    SDL_Texture* texture = nullptr;
    int width = 0;
    int height = 0;
    int atlasWidth = 0;
    int atlasHeight = 0;
    int cellWidth = 0;
    int cellHeight = 0;
    bool stackedAtlas = false;
};

struct TextSegment {
    std::string text;
    SDL_FColor color;
};

enum CurlOption {
    CurlOptUrl = 1,
    CurlOptHttpHeader,
    CurlOptUserAgent,
    CurlOptAcceptEncoding,
    CurlOptFollowLocation,
    CurlOptPost,
    CurlOptPostFields,
    CurlOptIpResolve,
    CurlOptProxy,
    CurlOptSslVerifyPeer,
    CurlOptSslVerifyHost,
};

enum CurlInfo {
    CurlInfoResponseCode = 1,
    CurlInfoSizeDownload,
    CurlInfoRedirectUrl,
};

struct CurlEasy {
    CURL* curl = nullptr;
    curl_slist* headers = nullptr;
    int writeRef = LUA_NOREF;
    int headerRef = LUA_NOREF;
    long responseCode = 0;
};

struct CurlCallbackState {
    lua_State* L = nullptr;
    int ref = LUA_NOREF;
};

bool fileExists(const fs::path& path);

std::string luaString(lua_State* L, int index) {
    size_t len = 0;
    const char* value = luaL_checklstring(L, index, &len);
    return std::string(value, len);
}

void pushString(lua_State* L, const std::string& value) {
    lua_pushlstring(L, value.data(), value.size());
}

std::string stripEscapes(std::string text) {
    std::string out;
    out.reserve(text.size());
    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '^' && i + 1 < text.size()) {
            if (text[i + 1] >= '0' && text[i + 1] <= '9') {
                ++i;
                continue;
            }
            if (text[i + 1] == 'x' && i + 7 < text.size()) {
                i += 7;
                continue;
            }
        }
        out.push_back(text[i]);
    }
    return out;
}

SDL_FColor escapeColor(char code, SDL_FColor fallback) {
    switch (code) {
        case '0': return {0.0f, 0.0f, 0.0f, fallback.a};
        case '1': return {1.0f, 0.0f, 0.0f, fallback.a};
        case '2': return {0.0f, 0.7f, 0.0f, fallback.a};
        case '3': return {0.0f, 0.35f, 1.0f, fallback.a};
        case '4': return {1.0f, 0.85f, 0.0f, fallback.a};
        case '5': return {0.8f, 0.0f, 1.0f, fallback.a};
        case '6': return {0.0f, 0.8f, 1.0f, fallback.a};
        case '7': return {1.0f, 1.0f, 1.0f, fallback.a};
        case '8': return {0.55f, 0.55f, 0.55f, fallback.a};
        case '9': return {0.9f, 0.55f, 0.15f, fallback.a};
        default: return fallback;
    }
}

SDL_FColor parseColorString(const std::string& value, SDL_FColor fallback) {
    if (value.size() >= 2 && value[0] == '^' && value[1] >= '0' && value[1] <= '9') {
        return escapeColor(value[1], fallback);
    }
    if (value.size() >= 8 && value[0] == '^' && value[1] == 'x') {
        auto hex = value.substr(2, 6);
        char* end = nullptr;
        long parsed = std::strtol(hex.c_str(), &end, 16);
        if (end && *end == '\0') {
            return {
                static_cast<float>((parsed >> 16) & 0xFF) / 255.0f,
                static_cast<float>((parsed >> 8) & 0xFF) / 255.0f,
                static_cast<float>(parsed & 0xFF) / 255.0f,
                fallback.a
            };
        }
    }
    return fallback;
}

void renderDebugTextWithEscapes(SDL_Renderer* renderer, float x, float y, const std::string& text, SDL_FColor fallback, float scale) {
    SDL_FColor color = fallback;
    float cursor = x;
    std::string segment;

    auto flush = [&]() {
        if (segment.empty()) {
            return;
        }
        SDL_SetRenderDrawColorFloat(renderer, color.r, color.g, color.b, color.a);
        SDL_RenderDebugText(renderer, cursor / scale, y / scale, segment.c_str());
        cursor += static_cast<float>(segment.size() * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE) * scale;
        segment.clear();
    };

    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '^' && i + 1 < text.size()) {
            if (text[i + 1] >= '0' && text[i + 1] <= '9') {
                flush();
                color = escapeColor(text[i + 1], fallback);
                ++i;
                continue;
            }
            if (text[i + 1] == 'x' && i + 7 < text.size()) {
                flush();
                auto hex = text.substr(i + 2, 6);
                char* end = nullptr;
                long value = std::strtol(hex.c_str(), &end, 16);
                if (end && *end == '\0') {
                    color = {
                        static_cast<float>((value >> 16) & 0xFF) / 255.0f,
                        static_cast<float>((value >> 8) & 0xFF) / 255.0f,
                        static_cast<float>(value & 0xFF) / 255.0f,
                        fallback.a
                    };
                }
                i += 7;
                continue;
            }
        }
        segment.push_back(text[i]);
    }
    flush();
}

std::vector<TextSegment> splitTextSegments(const std::string& text, SDL_FColor fallback) {
    std::vector<TextSegment> segments;
    SDL_FColor color = fallback;
    std::string segment;
    auto flush = [&]() {
        if (!segment.empty()) {
            segments.push_back({segment, color});
            segment.clear();
        }
    };

    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '^' && i + 1 < text.size()) {
            if (text[i + 1] >= '0' && text[i + 1] <= '9') {
                flush();
                color = escapeColor(text[i + 1], fallback);
                ++i;
                continue;
            }
            if (text[i + 1] == 'x' && i + 7 < text.size()) {
                flush();
                color = parseColorString(text.substr(i, 8), fallback);
                i += 7;
                continue;
            }
        }
        segment.push_back(text[i]);
    }
    flush();
    return segments;
}

std::string keyNameFromSdl(SDL_Keycode key) {
    if (key >= SDLK_A && key <= SDLK_Z) {
        return std::string(1, static_cast<char>('a' + (key - SDLK_A)));
    }
    if (key >= SDLK_0 && key <= SDLK_9) {
        return std::string(1, static_cast<char>('0' + (key - SDLK_0)));
    }
    switch (key) {
        case SDLK_RETURN:
        case SDLK_KP_ENTER: return "RETURN";
        case SDLK_ESCAPE: return "ESCAPE";
        case SDLK_BACKSPACE: return "BACK";
        case SDLK_DELETE: return "DELETE";
        case SDLK_TAB: return "TAB";
        case SDLK_SPACE: return "SPACE";
        case SDLK_LEFT: return "LEFT";
        case SDLK_RIGHT: return "RIGHT";
        case SDLK_UP: return "UP";
        case SDLK_DOWN: return "DOWN";
        case SDLK_HOME: return "HOME";
        case SDLK_END: return "END";
        case SDLK_PAGEUP: return "PAGEUP";
        case SDLK_PAGEDOWN: return "PAGEDOWN";
        case SDLK_INSERT: return "INSERT";
        case SDLK_F1: return "F1";
        case SDLK_F2: return "F2";
        case SDLK_F3: return "F3";
        case SDLK_F4: return "F4";
        case SDLK_F5: return "F5";
        case SDLK_F6: return "F6";
        case SDLK_F7: return "F7";
        case SDLK_F8: return "F8";
        case SDLK_F9: return "F9";
        case SDLK_F10: return "F10";
        case SDLK_F11: return "F11";
        case SDLK_F12: return "F12";
        case SDLK_PRINTSCREEN: return "PRINTSCREEN";
        case SDLK_LCTRL:
        case SDLK_RCTRL:
        // Map the macOS Command (⌘) key to PoB's CTRL so the documented Ctrl
        // shortcuts (⌘C/⌘V/⌘S/⌘Z/⌘F, ⌘-click, etc.) work natively. The physical
        // Control key continues to work as well.
        case SDLK_LGUI:
        case SDLK_RGUI: return "CTRL";
        case SDLK_LSHIFT:
        case SDLK_RSHIFT: return "SHIFT";
        case SDLK_LALT:
        case SDLK_RALT: return "ALT";
        case SDLK_MINUS: return "-";
        case SDLK_EQUALS: return "=";
        case SDLK_COMMA: return ",";
        case SDLK_PERIOD: return ".";
        case SDLK_SLASH: return "/";
        case SDLK_SEMICOLON: return ";";
        case SDLK_APOSTROPHE: return "'";
        case SDLK_LEFTBRACKET: return "[";
        case SDLK_RIGHTBRACKET: return "]";
        case SDLK_BACKSLASH: return "\\";
        case SDLK_GRAVE: return "`";
        default: return "";
    }
}

void setModifierStates(std::unordered_set<std::string>& keyState) {
    SDL_Keymod mods = SDL_GetModState();
    // Treat the macOS Command (⌘) key as CTRL for native-feeling shortcuts.
    if (mods & (SDL_KMOD_CTRL | SDL_KMOD_GUI)) keyState.insert("CTRL"); else keyState.erase("CTRL");
    if (mods & SDL_KMOD_SHIFT) keyState.insert("SHIFT"); else keyState.erase("SHIFT");
    if (mods & SDL_KMOD_ALT) keyState.insert("ALT"); else keyState.erase("ALT");
}

std::string registryString(lua_State* L, const char* key) {
    lua_getfield(L, LUA_REGISTRYINDEX, key);
    std::string value = lua_tostring(L, -1) ? lua_tostring(L, -1) : "";
    lua_pop(L, 1);
    return value;
}

std::vector<unsigned char> readFileBytes(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        return {};
    }
    return std::vector<unsigned char>(std::istreambuf_iterator<char>(input), {});
}

fs::path resolveAssetPath(lua_State* L, const std::string& fileName) {
    fs::path path(fileName);
    if (path.is_absolute() && fileExists(path)) {
        return path;
    }

    std::vector<fs::path> roots = {
        fs::current_path(),
        registryString(L, kScriptPath),
        fs::path(registryString(L, kRuntimePath)) / "SimpleGraphic",
        registryString(L, kRuntimePath),
    };
    for (const auto& root : roots) {
        if (root.empty()) {
            continue;
        }
        fs::path candidate = root / path;
        if (fileExists(candidate)) {
            return candidate;
        }
    }
    return path;
}

NativeImage* createTextureFromRgba(SDL_Renderer* renderer, int width, int height, const std::vector<unsigned char>& rgba) {
    if (!renderer || width <= 0 || height <= 0 || rgba.empty()) {
        return nullptr;
    }
    SDL_Surface* surface = SDL_CreateSurfaceFrom(
        width,
        height,
        SDL_PIXELFORMAT_RGBA32,
        const_cast<unsigned char*>(rgba.data()),
        width * 4
    );
    if (!surface) {
        return nullptr;
    }
    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_DestroySurface(surface);
    if (!texture) {
        return nullptr;
    }
    SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
    auto* image = new NativeImage();
    image->texture = texture;
    image->width = width;
    image->height = height;
    image->atlasWidth = width;
    image->atlasHeight = height;
    image->cellWidth = width;
    image->cellHeight = height;
    return image;
}

NativeImage* createTextureFromDecodedDds(SDL_Renderer* renderer, const DecodedDds& decoded) {
    auto* image = createTextureFromRgba(renderer, decoded.atlasWidth, decoded.atlasHeight, decoded.rgba);
    if (!image) {
        return nullptr;
    }
    if (decoded.stackedAtlas) {
        image->width = decoded.cellWidth;
        image->height = decoded.cellHeight;
        image->cellWidth = decoded.cellWidth;
        image->cellHeight = decoded.cellHeight;
        image->stackedAtlas = true;
    }
    return image;
}

bool endsWithIgnoreCase(const std::string& value, const std::string& suffix) {
    if (value.size() < suffix.size()) {
        return false;
    }
    for (size_t i = 0; i < suffix.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(value[value.size() - suffix.size() + i])) !=
            std::tolower(static_cast<unsigned char>(suffix[i]))) {
            return false;
        }
    }
    return true;
}

NativeImage* loadDdsImage(SDL_Renderer* renderer, const fs::path& path) {
    auto data = readFileBytes(path);
    if (data.empty()) {
        return nullptr;
    }

    std::vector<unsigned char> ddsData;
    if (endsWithIgnoreCase(path.string(), ".dds.zst")) {
        if (!zstdDecompressBytes(data, ddsData)) {
            std::fprintf(stderr, "Failed to decompress zstd image: %s\n", path.string().c_str());
            return nullptr;
        }
    } else {
        ddsData = std::move(data);
    }

    DecodedDds decoded;
    if (!decodeDdsBytes(ddsData, decoded)) {
        std::fprintf(stderr, "Failed to decode DDS image: %s\n", path.string().c_str());
        return nullptr;
    }
    return createTextureFromDecodedDds(renderer, decoded);
}

bool isStackIndexDraw(float tcLeft, float tcTop, float tcRight, float tcBottom) {
    return tcLeft >= 1.0f &&
        tcLeft == std::floor(tcLeft) &&
        tcTop == 0.0f &&
        tcRight == 1.0f &&
        tcBottom == 1.0f;
}

bool sourceRectForImage(
    NativeImage* image,
    float tcLeft,
    float tcTop,
    float tcRight,
    float tcBottom,
    SDL_FRect& src
) {
    if (!image || image->atlasWidth <= 0 || image->atlasHeight <= 0) {
        return false;
    }

    if (image->stackedAtlas && isStackIndexDraw(tcLeft, tcTop, tcRight, tcBottom)) {
        const int index = std::max(0, static_cast<int>(tcLeft) - 1);
        const int cols = std::max(1, image->atlasWidth / std::max(1, image->cellWidth));
        const int col = index % cols;
        const int row = index / cols;
        src.x = static_cast<float>(col * image->cellWidth);
        src.y = static_cast<float>(row * image->cellHeight);
        src.w = static_cast<float>(image->cellWidth);
        src.h = static_cast<float>(image->cellHeight);
        return true;
    }

    const float atlasW = static_cast<float>(image->atlasWidth);
    const float atlasH = static_cast<float>(image->atlasHeight);
    src.x = tcLeft * atlasW;
    src.y = tcTop * atlasH;
    src.w = (tcRight - tcLeft) * atlasW;
    src.h = (tcBottom - tcTop) * atlasH;
    if (src.w < 0.0f) {
        src.x += src.w;
        src.w = -src.w;
    }
    if (src.h < 0.0f) {
        src.y += src.h;
        src.h = -src.h;
    }
    return src.w > 0.0f && src.h > 0.0f;
}

bool isStackIndexQuadDraw(float s1, float t1, float s2, float t2, float s3, float t3, float s4, float t4) {
    return s1 >= 1.0f &&
        s1 == std::floor(s1) &&
        t1 == 0.0f &&
        t2 == 0.0f &&
        t3 == 0.0f &&
        t4 == 0.0f &&
        s2 == 0.0f &&
        s3 == 0.0f &&
        s4 == 0.0f;
}

void stackIndexTexCoords(NativeImage* image, float stackIndex, float& s1, float& t1, float& s2, float& t2, float& s3, float& t3, float& s4, float& t4) {
    const int index = std::max(0, static_cast<int>(stackIndex) - 1);
    const float atlasW = static_cast<float>(image->atlasWidth);
    const float atlasH = static_cast<float>(image->atlasHeight);
    const int cols = std::max(1, image->atlasWidth / std::max(1, image->cellWidth));
    const int col = index % cols;
    const int row = index / cols;
    const float left = static_cast<float>(col * image->cellWidth) / atlasW;
    const float right = static_cast<float>((col + 1) * image->cellWidth) / atlasW;
    const float top = static_cast<float>(row * image->cellHeight) / atlasH;
    const float bottom = static_cast<float>((row + 1) * image->cellHeight) / atlasH;
    s1 = left;
    t1 = top;
    s2 = right;
    t2 = top;
    s3 = right;
    t3 = bottom;
    s4 = left;
    t4 = bottom;
}

NativeImage* loadCocoaImage(SDL_Renderer* renderer, const fs::path& path) {
    @autoreleasepool {
        NSString* nsPath = [NSString stringWithUTF8String:path.string().c_str()];
        NSImage* nsImage = [[NSImage alloc] initWithContentsOfFile:nsPath];
        if (!nsImage) {
            return nullptr;
        }
        CGImageRef cgImage = [nsImage CGImageForProposedRect:nil context:nil hints:nil];
        if (!cgImage) {
            return nullptr;
        }
        int width = static_cast<int>(CGImageGetWidth(cgImage));
        int height = static_cast<int>(CGImageGetHeight(cgImage));
        std::vector<unsigned char> rgba(static_cast<size_t>(width) * height * 4);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(
            rgba.data(),
            width,
            height,
            8,
            width * 4,
            colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
        );
        CGColorSpaceRelease(colorSpace);
        if (!context) {
            return nullptr;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
        CGContextRelease(context);
        return createTextureFromRgba(renderer, width, height, rgba);
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
        ++pixelIndex;
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

NativeImage* loadTgaImage(SDL_Renderer* renderer, const fs::path& path) {
    auto data = readFileBytes(path);
    int width = 0;
    int height = 0;
    std::vector<unsigned char> rgba;
    if (!decodeTgaPixels(data, width, height, rgba)) {
        return nullptr;
    }
    return createTextureFromRgba(renderer, width, height, rgba);
}

NativeImage* loadNativeImage(lua_State* L, SDL_Renderer* renderer, const std::string& fileName) {
    fs::path path = resolveAssetPath(L, fileName);
    const std::string pathString = path.string();
    if (endsWithIgnoreCase(pathString, ".dds.zst") || endsWithIgnoreCase(pathString, ".dds")) {
        return loadDdsImage(renderer, path);
    }
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (ext == ".tga") {
        return loadTgaImage(renderer, path);
    }
    if (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".webp") {
        return loadCocoaImage(renderer, path);
    }
    std::fprintf(stderr, "Unsupported image format: %s\n", fileName.c_str());
    return nullptr;
}

NativeImage* imageFromLua(lua_State* L, int index) {
    if (!lua_istable(L, index)) {
        return nullptr;
    }
    lua_getfield(L, index, "__native");
    auto* image = static_cast<NativeImage*>(lua_touserdata(L, -1));
    lua_pop(L, 1);
    return image;
}

CurlEasy* checkCurlEasy(lua_State* L, int index) {
    return static_cast<CurlEasy*>(luaL_checkudata(L, index, "PoB.CurlEasy"));
}

size_t curlWriteCallback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* state = static_cast<CurlCallbackState*>(userdata);
    size_t len = size * nmemb;
    lua_State* L = state->L;
    int ref = state->ref;
    if (ref == LUA_NOREF) {
        return len;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    lua_pushlstring(L, ptr, len);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        std::fprintf(stderr, "curl callback error: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
        return 0;
    }
    lua_pop(L, 1);
    return len;
}

int pushCurlError(lua_State* L, CURLcode code) {
    lua_pushnil(L);
    lua_newtable(L);
    lua_pushstring(L, curl_easy_strerror(code));
    lua_setfield(L, -2, "message");
    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_getfield(L, 1, "message");
        return 1;
    });
    lua_setfield(L, -2, "msg");
    return 2;
}

void registerFunction(lua_State* L, const char* name, lua_CFunction fn) {
    lua_pushcfunction(L, fn);
    lua_setglobal(L, name);
}

bool fileExists(const fs::path& path) {
    std::error_code ec;
    return fs::is_regular_file(path, ec);
}

fs::path findRepoRoot(fs::path start) {
    start = fs::absolute(start);
    for (fs::path path = start; !path.empty(); path = path.parent_path()) {
        if (fileExists(path / "src" / "Launch.lua")) {
            return path;
        }
        if (path == path.parent_path()) {
            break;
        }
    }
    return start;
}

fs::path bundleResourcesPath() {
    @autoreleasepool {
        NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
        if (resourcePath) {
            return fs::path([resourcePath UTF8String]);
        }
    }
    return {};
}

std::string applicationSupportPath() {
    @autoreleasepool {
        NSArray<NSURL*>* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        if ([urls count] == 0) {
            return "";
        }
        return std::string([[[urls objectAtIndex:0] path] UTF8String]);
    }
}

std::vector<unsigned char> rawDeflate(const std::string& input) {
    z_stream stream{};
    if (deflateInit(&stream, Z_BEST_COMPRESSION) != Z_OK) {
        return {};
    }
    stream.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(input.data()));
    stream.avail_in = static_cast<uInt>(input.size());
    std::vector<unsigned char> out(deflateBound(&stream, static_cast<uLong>(input.size())));
    stream.next_out = out.data();
    stream.avail_out = static_cast<uInt>(out.size());
    const int err = deflate(&stream, Z_FINISH);
    deflateEnd(&stream);
    if (err != Z_STREAM_END) {
        return {};
    }
    out.resize(stream.total_out);
    return out;
}

std::vector<unsigned char> rawInflate(const std::string& input) {
    if (input.empty()) {
        return {};
    }
    z_stream stream{};
    stream.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(input.data()));
    stream.avail_in = static_cast<uInt>(input.size());
    if (inflateInit(&stream) != Z_OK) {
        return {};
    }
    size_t outSz = input.size() * 4;
    std::vector<unsigned char> out(outSz);
    stream.next_out = out.data();
    stream.avail_out = static_cast<uInt>(outSz);
    int err = Z_OK;
    while ((err = inflate(&stream, Z_NO_FLUSH)) == Z_OK) {
        if (stream.avail_out == 0) {
            if (outSz > 128ull << 20) {
                inflateEnd(&stream);
                return {};
            }
            const size_t oldSz = outSz;
            outSz *= 2;
            out.resize(outSz);
            stream.next_out = out.data() + oldSz;
            stream.avail_out = static_cast<uInt>(outSz - oldSz);
        }
    }
    inflateEnd(&stream);
    if (err != Z_STREAM_END) {
        return {};
    }
    out.resize(stream.total_out);
    return out;
}
}

Host* Host::current = nullptr;

Host::Host() {
    current = this;
}

Host::~Host() {
    subScriptManager.shutdown();
    if (L) {
        lua_close(L);
    }
    if (renderer) {
        SDL_DestroyRenderer(renderer);
    }
    if (window) {
        SDL_DestroyWindow(window);
    }
    SDL_Quit();
    curl_global_cleanup();
    current = nullptr;
}

bool Host::init(int argc, char** argv) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return false;
    }
    if (!initLua(argc, argv)) {
        return false;
    }
    return loadLaunchScript();
}

bool Host::initLua(int argc, char** argv) {
    L = luaL_newstate();
    if (!L) {
        return false;
    }
    luaL_openlibs(L);
    registerApi();

    lua_newtable(L);
    for (int i = 0; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, kCallbacks);

    setSearchPaths();
    registerPreloadModules();
    return true;
}

// Minimal native LuaSocket-compatible TCP shim. PoB only uses this for the
// OAuth loopback redirect server in src/LaunchServer.lua, so we implement just
// the subset of the LuaSocket API that script relies on. The module is exposed
// through package.preload so it shadows the Windows-only runtime/lua/socket.lua
// wrapper (which depends on the native socket.dll that does not exist on macOS).
namespace {
constexpr const char* kSocketMeta = "PoB.Socket";

struct NativeSocket {
    int fd = -1;
    double timeout = -1.0; // <0 blocking, 0 non-blocking, >0 timeout in seconds
};

NativeSocket* checkSocket(lua_State* L, int idx) {
    return static_cast<NativeSocket*>(luaL_checkudata(L, idx, kSocketMeta));
}

bool socketWaitReady(int fd, double timeout, bool forWrite) {
    if (fd < 0) {
        return false;
    }
    fd_set set;
    FD_ZERO(&set);
    FD_SET(fd, &set);
    timeval tv{};
    timeval* ptv = nullptr;
    if (timeout >= 0) {
        tv.tv_sec = static_cast<long>(timeout);
        tv.tv_usec = static_cast<long>((timeout - static_cast<double>(tv.tv_sec)) * 1e6);
        ptv = &tv;
    }
    int result = select(fd + 1, forWrite ? nullptr : &set, forWrite ? &set : nullptr, nullptr, ptv);
    return result > 0;
}

void configureSocket(int fd) {
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
}

int socketPushNew(lua_State* L, int fd) {
    auto* sock = static_cast<NativeSocket*>(lua_newuserdata(L, sizeof(NativeSocket)));
    sock->fd = fd;
    sock->timeout = -1.0;
    luaL_getmetatable(L, kSocketMeta);
    lua_setmetatable(L, -2);
    return 1;
}

int sock_tcp4(lua_State* L) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        lua_pushnil(L);
        lua_pushstring(L, std::strerror(errno));
        return 2;
    }
    configureSocket(fd);
    return socketPushNew(L, fd);
}

int sock_setoption(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    const char* option = luaL_checkstring(L, 2);
    if (std::strcmp(option, "reuseaddr") == 0) {
        int value = lua_toboolean(L, 3) ? 1 : 0;
        setsockopt(sock->fd, SOL_SOCKET, SO_REUSEADDR, &value, sizeof(value));
    }
    lua_pushinteger(L, 1);
    return 1;
}

bool resolveHost(const char* host, in_addr& out) {
    if (host == nullptr || *host == '\0' || std::strcmp(host, "*") == 0 || std::strcmp(host, "0.0.0.0") == 0) {
        out.s_addr = htonl(INADDR_ANY);
        return true;
    }
    if (std::strcmp(host, "localhost") == 0) {
        out.s_addr = htonl(INADDR_LOOPBACK);
        return true;
    }
    if (inet_pton(AF_INET, host, &out) == 1) {
        return true;
    }
    addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    addrinfo* info = nullptr;
    if (getaddrinfo(host, nullptr, &hints, &info) == 0 && info) {
        out = reinterpret_cast<sockaddr_in*>(info->ai_addr)->sin_addr;
        freeaddrinfo(info);
        return true;
    }
    return false;
}

int sock_bind(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    const char* host = luaL_checkstring(L, 2);
    int port = static_cast<int>(luaL_checkinteger(L, 3));
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<uint16_t>(port));
    if (!resolveHost(host, addr.sin_addr)) {
        lua_pushnil(L);
        lua_pushstring(L, "host not found");
        return 2;
    }
    if (bind(sock->fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        lua_pushnil(L);
        lua_pushstring(L, std::strerror(errno));
        return 2;
    }
    lua_pushinteger(L, 1);
    return 1;
}

int sock_listen(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    int backlog = static_cast<int>(luaL_optinteger(L, 2, 5));
    if (listen(sock->fd, backlog) < 0) {
        lua_pushnil(L);
        lua_pushstring(L, std::strerror(errno));
        return 2;
    }
    lua_pushinteger(L, 1);
    return 1;
}

int sock_getsockname(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    sockaddr_in addr{};
    socklen_t len = sizeof(addr);
    if (getsockname(sock->fd, reinterpret_cast<sockaddr*>(&addr), &len) < 0) {
        lua_pushnil(L);
        lua_pushstring(L, std::strerror(errno));
        return 2;
    }
    char buf[INET_ADDRSTRLEN] = {0};
    inet_ntop(AF_INET, &addr.sin_addr, buf, sizeof(buf));
    lua_pushstring(L, buf);
    lua_pushinteger(L, ntohs(addr.sin_port));
    return 2;
}

int sock_settimeout(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    if (lua_isnoneornil(L, 2)) {
        sock->timeout = -1.0;
    } else {
        sock->timeout = luaL_checknumber(L, 2);
    }
    lua_pushinteger(L, 1);
    return 1;
}

int sock_accept(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    if (sock->timeout >= 0 && !socketWaitReady(sock->fd, sock->timeout, false)) {
        lua_pushnil(L);
        lua_pushstring(L, "timeout");
        return 2;
    }
    int clientFd = accept(sock->fd, nullptr, nullptr);
    if (clientFd < 0) {
        lua_pushnil(L);
        lua_pushstring(L, std::strerror(errno));
        return 2;
    }
    configureSocket(clientFd);
    return socketPushNew(L, clientFd);
}

int sock_receive(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    const char* pattern = luaL_optstring(L, 2, "*l");
    bool lineMode = std::strcmp(pattern, "*l") == 0 || std::strcmp(pattern, "l") == 0;
    bool allMode = std::strcmp(pattern, "*a") == 0 || std::strcmp(pattern, "a") == 0;
    std::string out;
    while (true) {
        if (sock->timeout >= 0 && !socketWaitReady(sock->fd, sock->timeout, false)) {
            lua_pushnil(L);
            lua_pushstring(L, "timeout");
            lua_pushlstring(L, out.data(), out.size());
            return 3;
        }
        char ch = 0;
        ssize_t n = recv(sock->fd, &ch, 1, 0);
        if (n == 0) {
            if (allMode) {
                break;
            }
            lua_pushnil(L);
            lua_pushstring(L, "closed");
            lua_pushlstring(L, out.data(), out.size());
            return 3;
        }
        if (n < 0) {
            lua_pushnil(L);
            lua_pushstring(L, std::strerror(errno));
            lua_pushlstring(L, out.data(), out.size());
            return 3;
        }
        if (lineMode) {
            if (ch == '\n') {
                break;
            }
            if (ch == '\r') {
                continue;
            }
        }
        out.push_back(ch);
    }
    lua_pushlstring(L, out.data(), out.size());
    return 1;
}

int sock_send(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    size_t len = 0;
    const char* data = luaL_checklstring(L, 2, &len);
    size_t sent = 0;
    while (sent < len) {
        if (sock->timeout >= 0 && !socketWaitReady(sock->fd, sock->timeout, true)) {
            lua_pushnil(L);
            lua_pushstring(L, "timeout");
            lua_pushinteger(L, static_cast<lua_Integer>(sent));
            return 3;
        }
        ssize_t n = send(sock->fd, data + sent, len - sent, 0);
        if (n < 0) {
            lua_pushnil(L);
            lua_pushstring(L, std::strerror(errno));
            lua_pushinteger(L, static_cast<lua_Integer>(sent));
            return 3;
        }
        sent += static_cast<size_t>(n);
    }
    lua_pushinteger(L, static_cast<lua_Integer>(sent));
    return 1;
}

int sock_close(lua_State* L) {
    NativeSocket* sock = checkSocket(L, 1);
    if (sock->fd >= 0) {
        close(sock->fd);
        sock->fd = -1;
    }
    return 0;
}

int sock_gc(lua_State* L) {
    auto* sock = static_cast<NativeSocket*>(luaL_checkudata(L, 1, kSocketMeta));
    if (sock->fd >= 0) {
        close(sock->fd);
        sock->fd = -1;
    }
    return 0;
}

int socketLoader(lua_State* L) {
    if (luaL_newmetatable(L, kSocketMeta)) {
        lua_pushcfunction(L, sock_gc);
        lua_setfield(L, -2, "__gc");
        lua_newtable(L);
        const luaL_Reg methods[] = {
            {"setoption", sock_setoption},
            {"bind", sock_bind},
            {"listen", sock_listen},
            {"getsockname", sock_getsockname},
            {"settimeout", sock_settimeout},
            {"accept", sock_accept},
            {"receive", sock_receive},
            {"send", sock_send},
            {"close", sock_close},
            {nullptr, nullptr},
        };
        for (const luaL_Reg* m = methods; m->name; ++m) {
            lua_pushcfunction(L, m->func);
            lua_setfield(L, -2, m->name);
        }
        lua_setfield(L, -2, "__index");
    }
    lua_pop(L, 1);

    lua_newtable(L);
    lua_pushcfunction(L, sock_tcp4);
    lua_setfield(L, -2, "tcp4");
    lua_pushcfunction(L, sock_tcp4);
    lua_setfield(L, -2, "tcp");
    return 1;
}
} // namespace

void Host::registerPreloadModules() {
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");

    lua_pushcfunction(L, socketLoader);
    lua_setfield(L, -2, "socket");


    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_newtable(L);

        lua_pushinteger(L, CurlOptHttpHeader); lua_setfield(L, -2, "OPT_HTTPHEADER");
        lua_pushinteger(L, CurlOptUserAgent); lua_setfield(L, -2, "OPT_USERAGENT");
        lua_pushinteger(L, CurlOptAcceptEncoding); lua_setfield(L, -2, "OPT_ACCEPT_ENCODING");
        lua_pushinteger(L, CurlOptFollowLocation); lua_setfield(L, -2, "OPT_FOLLOWLOCATION");
        lua_pushinteger(L, CurlOptPost); lua_setfield(L, -2, "OPT_POST");
        lua_pushinteger(L, CurlOptPostFields); lua_setfield(L, -2, "OPT_POSTFIELDS");
        lua_pushinteger(L, CurlOptIpResolve); lua_setfield(L, -2, "OPT_IPRESOLVE");
        lua_pushinteger(L, CurlOptProxy); lua_setfield(L, -2, "OPT_PROXY");
        lua_pushinteger(L, CurlOptSslVerifyPeer); lua_setfield(L, -2, "OPT_SSL_VERIFYPEER");
        lua_pushinteger(L, CurlOptSslVerifyHost); lua_setfield(L, -2, "OPT_SSL_VERIFYHOST");
        lua_pushinteger(L, CurlInfoResponseCode); lua_setfield(L, -2, "INFO_RESPONSE_CODE");
        lua_pushinteger(L, CurlInfoSizeDownload); lua_setfield(L, -2, "INFO_SIZE_DOWNLOAD");
        lua_pushinteger(L, CurlInfoRedirectUrl); lua_setfield(L, -2, "INFO_REDIRECT_URL");

        if (luaL_newmetatable(L, "PoB.CurlEasy")) {
            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                if (easy->headers) {
                    curl_slist_free_all(easy->headers);
                    easy->headers = nullptr;
                }
                if (easy->writeRef != LUA_NOREF) {
                    luaL_unref(L, LUA_REGISTRYINDEX, easy->writeRef);
                    easy->writeRef = LUA_NOREF;
                }
                if (easy->headerRef != LUA_NOREF) {
                    luaL_unref(L, LUA_REGISTRYINDEX, easy->headerRef);
                    easy->headerRef = LUA_NOREF;
                }
                if (easy->curl) {
                    curl_easy_cleanup(easy->curl);
                    easy->curl = nullptr;
                }
                return 0;
            });
            lua_setfield(L, -2, "__gc");

            lua_newtable(L);
            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                curl_easy_setopt(easy->curl, CURLOPT_URL, luaL_checkstring(L, 2));
                return 0;
            });
            lua_setfield(L, -2, "setopt_url");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                curl_easy_setopt(easy->curl, CURLOPT_USERAGENT, luaL_checkstring(L, 2));
                return 0;
            });
            lua_setfield(L, -2, "setopt_useragent");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                int option = static_cast<int>(luaL_checkinteger(L, 2));
                switch (option) {
                    case CurlOptHttpHeader:
                        if (easy->headers) {
                            curl_slist_free_all(easy->headers);
                            easy->headers = nullptr;
                        }
                        luaL_checktype(L, 3, LUA_TTABLE);
                        for (int i = 1; ; ++i) {
                            lua_rawgeti(L, 3, i);
                            if (lua_isnil(L, -1)) {
                                lua_pop(L, 1);
                                break;
                            }
                            easy->headers = curl_slist_append(easy->headers, lua_tostring(L, -1));
                            lua_pop(L, 1);
                        }
                        curl_easy_setopt(easy->curl, CURLOPT_HTTPHEADER, easy->headers);
                        break;
                    case CurlOptUserAgent:
                        curl_easy_setopt(easy->curl, CURLOPT_USERAGENT, luaL_checkstring(L, 3));
                        break;
                    case CurlOptAcceptEncoding:
                        curl_easy_setopt(easy->curl, CURLOPT_ACCEPT_ENCODING, luaL_optstring(L, 3, ""));
                        break;
                    case CurlOptFollowLocation:
                        curl_easy_setopt(easy->curl, CURLOPT_FOLLOWLOCATION, lua_toboolean(L, 3) ? 1L : 0L);
                        break;
                    case CurlOptPost:
                        curl_easy_setopt(easy->curl, CURLOPT_POST, lua_toboolean(L, 3) ? 1L : 0L);
                        break;
                    case CurlOptPostFields:
                        curl_easy_setopt(easy->curl, CURLOPT_POSTFIELDS, luaL_checkstring(L, 3));
                        break;
                    case CurlOptIpResolve:
                        curl_easy_setopt(easy->curl, CURLOPT_IPRESOLVE, static_cast<long>(luaL_checkinteger(L, 3)));
                        break;
                    case CurlOptProxy:
                        curl_easy_setopt(easy->curl, CURLOPT_PROXY, luaL_checkstring(L, 3));
                        break;
                    case CurlOptSslVerifyPeer:
                        curl_easy_setopt(easy->curl, CURLOPT_SSL_VERIFYPEER, lua_toboolean(L, 3) ? 1L : 0L);
                        break;
                    case CurlOptSslVerifyHost:
                        curl_easy_setopt(easy->curl, CURLOPT_SSL_VERIFYHOST, lua_toboolean(L, 3) ? 2L : 0L);
                        break;
                    default:
                        break;
                }
                return 0;
            });
            lua_setfield(L, -2, "setopt");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                luaL_checktype(L, 2, LUA_TFUNCTION);
                lua_pushvalue(L, 2);
                if (easy->writeRef != LUA_NOREF) {
                    luaL_unref(L, LUA_REGISTRYINDEX, easy->writeRef);
                }
                easy->writeRef = luaL_ref(L, LUA_REGISTRYINDEX);
                return 0;
            });
            lua_setfield(L, -2, "setopt_writefunction");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                luaL_checktype(L, 2, LUA_TFUNCTION);
                lua_pushvalue(L, 2);
                if (easy->headerRef != LUA_NOREF) {
                    luaL_unref(L, LUA_REGISTRYINDEX, easy->headerRef);
                }
                easy->headerRef = luaL_ref(L, LUA_REGISTRYINDEX);
                return 0;
            });
            lua_setfield(L, -2, "setopt_headerfunction");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                CurlCallbackState writeState;
                writeState.L = L;
                writeState.ref = easy->writeRef;
                CurlCallbackState headerState;
                headerState.L = L;
                headerState.ref = easy->headerRef;
                curl_easy_setopt(easy->curl, CURLOPT_WRITEFUNCTION, curlWriteCallback);
                curl_easy_setopt(easy->curl, CURLOPT_WRITEDATA, &writeState);
                curl_easy_setopt(easy->curl, CURLOPT_HEADERFUNCTION, curlWriteCallback);
                curl_easy_setopt(easy->curl, CURLOPT_HEADERDATA, &headerState);
                CURLcode code = curl_easy_perform(easy->curl);
                curl_easy_getinfo(easy->curl, CURLINFO_RESPONSE_CODE, &easy->responseCode);
                if (code != CURLE_OK) {
                    return pushCurlError(L, code);
                }
                lua_pushboolean(L, 1);
                return 1;
            });
            lua_setfield(L, -2, "perform");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                int info = static_cast<int>(luaL_checkinteger(L, 2));
                if (info == CurlInfoResponseCode) {
                    long code = 0;
                    curl_easy_getinfo(easy->curl, CURLINFO_RESPONSE_CODE, &code);
                    lua_pushinteger(L, code);
                } else if (info == CurlInfoSizeDownload) {
                    curl_off_t size = 0;
                    curl_easy_getinfo(easy->curl, CURLINFO_SIZE_DOWNLOAD_T, &size);
                    lua_pushnumber(L, static_cast<lua_Number>(size));
                } else if (info == CurlInfoRedirectUrl) {
                    char* url = nullptr;
                    curl_easy_getinfo(easy->curl, CURLINFO_REDIRECT_URL, &url);
                    lua_pushstring(L, url ? url : "");
                } else {
                    lua_pushnil(L);
                }
                return 1;
            });
            lua_setfield(L, -2, "getinfo");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                long code = 0;
                curl_easy_getinfo(easy->curl, CURLINFO_RESPONSE_CODE, &code);
                lua_pushinteger(L, code);
                return 1;
            });
            lua_setfield(L, -2, "getinfo_response_code");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                auto* easy = checkCurlEasy(L, 1);
                char* escaped = curl_easy_escape(easy->curl, luaL_checkstring(L, 2), 0);
                lua_pushstring(L, escaped ? escaped : "");
                if (escaped) {
                    curl_free(escaped);
                }
                return 1;
            });
            lua_setfield(L, -2, "escape");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                luaL_callmeta(L, 1, "__gc");
                return 0;
            });
            lua_setfield(L, -2, "close");

            lua_setfield(L, -2, "__index");
        }
        lua_pop(L, 1);

        lua_pushcfunction(L, [](lua_State* L) -> int {
            auto* easy = static_cast<CurlEasy*>(lua_newuserdata(L, sizeof(CurlEasy)));
            new (easy) CurlEasy();
            easy->curl = curl_easy_init();
            curl_easy_setopt(easy->curl, CURLOPT_FOLLOWLOCATION, 1L);
            curl_easy_setopt(easy->curl, CURLOPT_ACCEPT_ENCODING, "");
            luaL_getmetatable(L, "PoB.CurlEasy");
            lua_setmetatable(L, -2);
            return 1;
        });
        lua_setfield(L, -2, "easy");

        return 1;
    });
    lua_setfield(L, -2, "lcurl.safe");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_newtable(L);
        lua_getglobal(L, "string");
        std::vector<const char*> names;
        names.push_back("match");
        names.push_back("gsub");
        names.push_back("find");
        names.push_back("sub");
        names.push_back(nullptr);
        for (const char* name : names) {
            if (!name) {
                break;
            }
            lua_getfield(L, -1, name);
            lua_setfield(L, -3, name);
        }
        lua_pop(L, 1);
        lua_pushcfunction(L, [](lua_State* L) -> int {
            std::string value = luaL_checkstring(L, 1);
            std::reverse(value.begin(), value.end());
            lua_pushlstring(L, value.data(), value.size());
            return 1;
        });
        lua_setfield(L, -2, "reverse");
        lua_pushcfunction(L, [](lua_State* L) -> int {
            std::string value = luaL_checkstring(L, 1);
            int index = static_cast<int>(luaL_checkinteger(L, 2));
            int step = static_cast<int>(luaL_optinteger(L, 3, 1));
            int next = index + step;
            if (next < 1 || next > static_cast<int>(value.size()) + 1) {
                lua_pushnil(L);
            } else {
                lua_pushinteger(L, next);
            }
            return 1;
        });
        lua_setfield(L, -2, "next");
        return 1;
    });
    lua_setfield(L, -2, "lua-utf8");

    lua_pop(L, 2);
}

void Host::setSearchPaths() {
    fs::path resources = bundleResourcesPath();
    fs::path scriptPath;
    fs::path runtimePath;

    if (!resources.empty() && fileExists(resources / "src" / "Launch.lua")) {
        scriptPath = resources / "src";
        runtimePath = resources / "runtime";
    } else {
        fs::path root = findRepoRoot(fs::current_path());
        scriptPath = root / "src";
        runtimePath = root / "runtime";
    }

    fs::current_path(scriptPath);
    lua_pushstring(L, scriptPath.string().c_str());
    lua_setfield(L, LUA_REGISTRYINDEX, kScriptPath);
    lua_pushstring(L, runtimePath.string().c_str());
    lua_setfield(L, LUA_REGISTRYINDEX, kRuntimePath);
    fontRenderer.setFontsDirectory(runtimePath / "SimpleGraphic" / "Fonts");

    lua_getglobal(L, "package");
    std::string luaPath = (runtimePath / "lua" / "?.lua").string() + ";" +
        (runtimePath / "lua" / "?" / "init.lua").string() + ";./?.lua;./?/init.lua";
    lua_pushstring(L, luaPath.c_str());
    lua_setfield(L, -2, "path");
    std::string luaCPath = (runtimePath / "?.so").string() + ";" + (runtimePath / "?.dylib").string();
    lua_pushstring(L, luaCPath.c_str());
    lua_setfield(L, -2, "cpath");
    lua_pop(L, 1);
}

bool Host::loadLaunchScript() {
    if (luaL_loadfile(L, "Launch.lua") != LUA_OK || lua_pcall(L, 0, 0, 0) != LUA_OK) {
        std::fprintf(stderr, "Launch.lua failed: %s\n", lua_tostring(L, -1));
        return false;
    }
    return true;
}

int Host::run() {
    callMainObject("OnInit");
    while (running) {
        pumpEvents();
        if (renderer) {
            SDL_SetRenderViewport(renderer, nullptr);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);
        }
        beginFrameDraw();
        subScriptManager.processFrame(L, kMainObject);
        callMainObject("OnFrame");
        if (renderer) {
            flushDrawCommands();
            SDL_SetRenderViewport(renderer, nullptr);
            SDL_RenderPresent(renderer);
        }
        SDL_Delay(16);
    }
    callMainObject("OnExit");
    return 0;
}

void Host::beginFrameDraw() {
    drawCommands.clear();
    drawSeq = 0;
    drawLayer = 0;
    drawSubLayer = 0;
    hasDrawViewport = false;
}

DrawCommand& Host::newDrawCommand(DrawCommand::Type type) {
    drawCommands.emplace_back();
    DrawCommand& cmd = drawCommands.back();
    cmd.type = type;
    cmd.layer = drawLayer;
    cmd.subLayer = drawSubLayer;
    cmd.seq = drawSeq++;
    cmd.hasViewport = hasDrawViewport;
    cmd.viewport = drawViewport;
    cmd.color = drawColor;
    return cmd;
}

void Host::flushDrawCommands() {
    std::stable_sort(drawCommands.begin(), drawCommands.end(),
        [](const DrawCommand& a, const DrawCommand& b) {
            if (a.layer != b.layer) return a.layer < b.layer;
            if (a.subLayer != b.subLayer) return a.subLayer < b.subLayer;
            return a.seq < b.seq;
        });

    const float scale = static_cast<float>(displayScale());
    static const int indices[6] = {0, 1, 2, 0, 2, 3};
    for (const DrawCommand& cmd : drawCommands) {
        if (cmd.hasViewport) {
            SDL_Rect vp{
                static_cast<int>(cmd.viewport.x * scale),
                static_cast<int>(cmd.viewport.y * scale),
                static_cast<int>(cmd.viewport.w * scale),
                static_cast<int>(cmd.viewport.h * scale),
            };
            SDL_SetRenderViewport(renderer, &vp);
        } else {
            SDL_SetRenderViewport(renderer, nullptr);
        }
        switch (cmd.type) {
            case DrawCommand::Type::Rect: {
                SDL_FRect r{cmd.rect.x * scale, cmd.rect.y * scale, cmd.rect.w * scale, cmd.rect.h * scale};
                SDL_SetRenderDrawColorFloat(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                SDL_RenderFillRect(renderer, &r);
                break;
            }
            case DrawCommand::Type::Texture:
                if (cmd.texture) {
                    SDL_FRect r{cmd.rect.x * scale, cmd.rect.y * scale, cmd.rect.w * scale, cmd.rect.h * scale};
                    SDL_SetTextureColorModFloat(cmd.texture, cmd.color.r, cmd.color.g, cmd.color.b);
                    SDL_SetTextureAlphaModFloat(cmd.texture, cmd.color.a);
                    SDL_RenderTexture(renderer, cmd.texture, cmd.hasSrc ? &cmd.src : nullptr, &r);
                }
                break;
            case DrawCommand::Type::Geometry: {
                SDL_Vertex verts[4];
                for (int i = 0; i < 4; ++i) {
                    verts[i] = cmd.verts[i];
                    verts[i].position.x *= scale;
                    verts[i].position.y *= scale;
                }
                if (cmd.geomTextured && cmd.texture) {
                    SDL_SetTextureColorModFloat(cmd.texture, cmd.color.r, cmd.color.g, cmd.color.b);
                    SDL_SetTextureAlphaModFloat(cmd.texture, cmd.color.a);
                    SDL_RenderGeometry(renderer, cmd.texture, verts, 4, indices, 6);
                } else {
                    SDL_RenderGeometry(renderer, nullptr, verts, 4, indices, 6);
                }
                break;
            }
            case DrawCommand::Type::Text:
                executeTextCommand(cmd, scale);
                break;
        }
    }
    drawCommands.clear();
}

void Host::executeTextCommand(const DrawCommand& cmd, float scale) {
    int screenWidth = 1600;
    if (window) {
        int h = 0;
        SDL_GetWindowSizeInPixels(window, &screenWidth, &h);
    }
    fontRenderer.setScreenWidth(screenWidth);

    // Render text directly in physical pixels: scale the requested font height and
    // position so the bitmap font atlas is sampled at native resolution (crisp),
    // rather than being drawn small and upscaled with the frame.
    const double physHeight = cmd.height * scale;
    std::istringstream lines(cmd.text);
    std::string line;
    float y = cmd.ty * scale;
    while (std::getline(lines, line)) {
        float x = cmd.tx * scale;
        const std::string cleanLine = stripEscapes(line);
        const double lineWidth = fontRenderer.stringWidth(physHeight, cmd.font, cleanLine);
        if (cmd.align == "CENTER") {
            x = std::floor((screenWidth - lineWidth) / 2.0f + cmd.tx * scale);
        } else if (cmd.align == "RIGHT") {
            x = std::floor(screenWidth - lineWidth - cmd.tx * scale);
        } else if (cmd.align == "CENTER_X") {
            x = std::floor(cmd.tx * scale - lineWidth / 2.0);
        } else if (cmd.align == "RIGHT_X") {
            x = std::floor(cmd.tx * scale - lineWidth);
        }
        for (const auto& segment : splitTextSegments(line, cmd.color)) {
            fontRenderer.drawString(renderer, x, y, "LEFT", physHeight, cmd.font, segment.text, segment.color);
            x += static_cast<float>(fontRenderer.stringWidth(physHeight, cmd.font, segment.text));
        }
        y += static_cast<float>(physHeight > 0 ? physHeight : 12);
    }
}

void Host::pumpEvents() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT) {
            running = false;
        } else if (event.type == SDL_EVENT_WINDOW_RESIZED) {
            updateLogicalPresentation();
        } else if (event.type == SDL_EVENT_MOUSE_MOTION) {
            mouseX = event.motion.x;
            mouseY = event.motion.y;
        } else if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN || event.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            mouseX = event.button.x;
            mouseY = event.button.y;
            std::string key;
            if (event.button.button == SDL_BUTTON_LEFT) {
                key = "LEFTBUTTON";
            } else if (event.button.button == SDL_BUTTON_RIGHT) {
                key = "RIGHTBUTTON";
            } else if (event.button.button == SDL_BUTTON_MIDDLE) {
                key = "MIDDLEBUTTON";
            }
            if (!key.empty()) {
                if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN) {
                    keyState.insert(key);
                    callMainObjectKey("OnKeyDown", key, event.button.clicks >= 2);
                } else {
                    keyState.erase(key);
                    callMainObjectKey("OnKeyUp", key);
                }
            }
        } else if (event.type == SDL_EVENT_MOUSE_WHEEL) {
            callMainObjectKey("OnKeyUp", event.wheel.y > 0 ? "WHEELUP" : "WHEELDOWN");
        } else if (event.type == SDL_EVENT_KEY_DOWN || event.type == SDL_EVENT_KEY_UP) {
            setModifierStates(keyState);
            std::string key = keyNameFromSdl(event.key.key);
            if (!key.empty()) {
                if (event.type == SDL_EVENT_KEY_DOWN) {
                    keyState.insert(key);
                    callMainObjectKey("OnKeyDown", key, event.key.repeat);
                } else {
                    keyState.erase(key);
                    callMainObjectKey("OnKeyUp", key);
                }
            }
        } else if (event.type == SDL_EVENT_TEXT_INPUT) {
            callMainObjectKey("OnChar", event.text.text);
        }
    }
}

void Host::callMainObject(const char* method) {
    lua_getfield(L, LUA_REGISTRYINDEX, kMainObject);
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }
    lua_getfield(L, -1, method);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return;
    }
    lua_pushvalue(L, -2);
    try {
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            std::fprintf(stderr, "In '%s': %s\n", method, lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    } catch (const std::bad_alloc& e) {
        std::fprintf(stderr, "In '%s': std::bad_alloc (out of memory): %s\n", method, e.what());
        lua_pop(L, 1);
    } catch (const std::exception& e) {
        std::fprintf(stderr, "In '%s': std::exception: %s\n", method, e.what());
        lua_pop(L, 1);
    } catch (...) {
        std::fprintf(stderr, "In '%s': unknown C++ exception\n", method);
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
}

void Host::callMainObjectKey(const char* method, const std::string& key, bool doubleClick) {
    lua_getfield(L, LUA_REGISTRYINDEX, kMainObject);
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }
    lua_getfield(L, -1, method);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return;
    }
    lua_pushvalue(L, -2);
    lua_pushlstring(L, key.data(), key.size());
    int args = 2;
    if (std::string(method) == "OnKeyDown") {
        lua_pushboolean(L, doubleClick);
        args = 3;
    }
    if (lua_pcall(L, args, 0, 0) != LUA_OK) {
        std::fprintf(stderr, "In %s(%s): %s\n", method, key.c_str(), lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
}

double Host::displayScale() const {
    double density = window ? SDL_GetWindowPixelDensity(window) : 1.0;
    if (density <= 0.0) {
        density = 1.0;
    }
    if (dpiScaleOverride > 0.0) {
        density *= dpiScaleOverride / 100.0;
    }
    return density;
}

void Host::updateLogicalPresentation() {
    if (!window || !renderer) {
        return;
    }
    // Render at the window's native pixel resolution (no upscaling). PoB lays out
    // in virtual/point coordinates and we scale draw commands to pixels at flush
    // time, which keeps bitmap fonts crisp on Retina displays instead of
    // stretching a low-resolution frame to fit the window.
    SDL_SetRenderLogicalPresentation(renderer, 0, 0, SDL_LOGICAL_PRESENTATION_DISABLED);
    int pw = 1600;
    int ph = 900;
    SDL_GetWindowSizeInPixels(window, &pw, &ph);
    fontRenderer.setScreenWidth(pw);
}

void Host::registerApi() {
    registerFunction(L, "SetMainObject", l_SetMainObject);
    registerFunction(L, "GetTime", l_GetTime);
    registerFunction(L, "SetWindowTitle", l_SetWindowTitle);
    registerFunction(L, "RenderInit", l_RenderInit);
    registerFunction(L, "GetScreenSize", l_GetScreenSize);
    registerFunction(L, "GetScreenScale", l_GetScreenScale);
    registerFunction(L, "GetVirtualScreenSize", l_GetVirtualScreenSize);
    registerFunction(L, "GetDPIScaleOverridePercent", l_GetDPIScaleOverridePercent);
    registerFunction(L, "SetDPIScaleOverridePercent", l_SetDPIScaleOverridePercent);
    registerFunction(L, "SetDrawColor", l_SetDrawColor);
    registerFunction(L, "GetDrawColor", l_GetDrawColor);
    registerFunction(L, "SetDrawLayer", l_SetDrawLayer);
    registerFunction(L, "SetViewport", l_SetViewport);
    registerFunction(L, "DrawImage", l_DrawImage);
    registerFunction(L, "DrawImageQuad", l_DrawImageQuad);
    registerFunction(L, "DrawString", l_DrawString);
    registerFunction(L, "DrawStringWidth", l_DrawStringWidth);
    registerFunction(L, "DrawStringCursorIndex", l_DrawStringCursorIndex);
    registerFunction(L, "StripEscapes", l_StripEscapes);
    registerFunction(L, "NewImageHandle", l_NewImageHandle);
    registerFunction(L, "SetCallback", l_SetCallback);
    registerFunction(L, "GetCallback", l_GetCallback);
    registerFunction(L, "GetCursorPos", l_GetCursorPos);
    registerFunction(L, "SetCursorPos", l_SetCursorPos);
    registerFunction(L, "ShowCursor", l_ShowCursor);
    registerFunction(L, "SetForeground", l_SetForeground);
    registerFunction(L, "IsKeyDown", l_IsKeyDown);
    registerFunction(L, "GetAsyncCount", l_GetAsyncCount);
    registerFunction(L, "Copy", l_Copy);
    registerFunction(L, "Paste", l_Paste);
    registerFunction(L, "GetScriptPath", l_GetScriptPath);
    registerFunction(L, "GetRuntimePath", l_GetRuntimePath);
    registerFunction(L, "GetUserPath", l_GetUserPath);
    registerFunction(L, "GetWorkDir", l_GetWorkDir);
    registerFunction(L, "SetWorkDir", l_SetWorkDir);
    registerFunction(L, "MakeDir", l_MakeDir);
    registerFunction(L, "RemoveDir", l_RemoveDir);
    registerFunction(L, "NewFileSearch", l_NewFileSearch);
    registerFunction(L, "OpenURL", l_OpenURL);
    registerFunction(L, "SpawnProcess", l_SpawnProcess);
    registerFunction(L, "Deflate", l_Deflate);
    registerFunction(L, "Inflate", l_Inflate);
    registerFunction(L, "LoadModule", l_LoadModule);
    registerFunction(L, "PLoadModule", l_PLoadModule);
    registerFunction(L, "PCall", l_PCall);
    registerFunction(L, "ConPrintf", l_ConPrintf);
    registerFunction(L, "ConExecute", l_ConExecute);
    registerFunction(L, "ConClear", l_ConClear);
    registerFunction(L, "Restart", l_Restart);
    registerFunction(L, "Exit", l_Exit);
    registerFunction(L, "LaunchSubScript", l_LaunchSubScript);
    registerFunction(L, "AbortSubScript", l_AbortSubScript);
    registerFunction(L, "IsSubScriptRunning", l_IsSubScriptRunning);
}

int Host::l_SetMainObject(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushvalue(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, kMainObject);
    return 0;
}

int Host::l_GetTime(lua_State* L) {
    auto now = std::chrono::steady_clock::now();
    lua_pushnumber(L, std::chrono::duration<double, std::milli>(now - startTime).count());
    return 1;
}

int Host::l_SetWindowTitle(lua_State* L) {
    if (current && current->window) {
        SDL_SetWindowTitle(current->window, luaL_checkstring(L, 1));
    }
    return 0;
}

int Host::l_RenderInit(lua_State*) {
    if (!current->window) {
        current->window = SDL_CreateWindow("Path of Building (PoE2)", 1600, 900, SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
        current->renderer = SDL_CreateRenderer(current->window, nullptr);
        // Enable alpha blending for solid fills and geometry (tooltip/popup
        // backgrounds and dimming overlays rely on translucent draws).
        SDL_SetRenderDrawBlendMode(current->renderer, SDL_BLENDMODE_BLEND);
        current->updateLogicalPresentation();
        SDL_StartTextInput(current->window);
    }
    return 0;
}

int Host::l_GetScreenSize(lua_State* L) {
    int w = 1600;
    int h = 900;
    if (current && current->window) {
        // PoB's DPI model expects the physical pixel size here; it divides by
        // GetScreenScale() to obtain the virtual (point) size it lays out in.
        SDL_GetWindowSizeInPixels(current->window, &w, &h);
    }
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    return 2;
}

int Host::l_GetScreenScale(lua_State* L) {
    lua_pushnumber(L, current ? current->displayScale() : 1.0);
    return 1;
}

int Host::l_GetVirtualScreenSize(lua_State* L) {
    int w = 1600;
    int h = 900;
    if (current && current->window) {
        SDL_GetWindowSizeInPixels(current->window, &w, &h);
        double scale = current->displayScale();
        if (scale > 0.0) {
            w = static_cast<int>(w / scale);
            h = static_cast<int>(h / scale);
        }
    }
    lua_pushinteger(L, w);
    lua_pushinteger(L, h);
    return 2;
}

int Host::l_GetDPIScaleOverridePercent(lua_State* L) {
    lua_pushnumber(L, current ? current->dpiScaleOverride : 0.0);
    return 1;
}

int Host::l_SetDPIScaleOverridePercent(lua_State* L) {
    if (current) {
        current->dpiScaleOverride = luaL_optnumber(L, 1, 0.0);
    }
    return 0;
}

int Host::l_SetDrawColor(lua_State* L) {
    if (current) {
        if (lua_isstring(L, 1) && !lua_isnumber(L, 1)) {
            current->drawColor = parseColorString(luaString(L, 1), current->drawColor);
        } else {
            current->drawColor.r = static_cast<float>(luaL_optnumber(L, 1, 1.0));
            current->drawColor.g = static_cast<float>(luaL_optnumber(L, 2, 1.0));
            current->drawColor.b = static_cast<float>(luaL_optnumber(L, 3, 1.0));
            current->drawColor.a = static_cast<float>(luaL_optnumber(L, 4, 1.0));
        }
    }
    return 0;
}
int Host::l_GetDrawColor(lua_State* L) {
    if (!current) {
        lua_pushnumber(L, 1.0); lua_pushnumber(L, 1.0);
        lua_pushnumber(L, 1.0); lua_pushnumber(L, 1.0);
        return 4;
    }
    lua_pushnumber(L, current->drawColor.r);
    lua_pushnumber(L, current->drawColor.g);
    lua_pushnumber(L, current->drawColor.b);
    lua_pushnumber(L, current->drawColor.a);
    return 4;
}
int Host::l_SetDrawLayer(lua_State* L) {
    if (!current) {
        return 0;
    }
    if (lua_isnoneornil(L, 1)) {
        // Keep the current layer, only change the sub-layer.
        current->drawSubLayer = static_cast<int>(luaL_optinteger(L, 2, 0));
    } else {
        current->drawLayer = static_cast<int>(luaL_checkinteger(L, 1));
        current->drawSubLayer = static_cast<int>(luaL_optinteger(L, 2, 0));
    }
    return 0;
}
int Host::l_SetViewport(lua_State* L) {
    if (!current) {
        return 0;
    }
    if (lua_gettop(L) < 4 || lua_isnil(L, 1)) {
        current->hasDrawViewport = false;
        return 0;
    }
    current->drawViewport = SDL_Rect{
        static_cast<int>(luaL_checknumber(L, 1)),
        static_cast<int>(luaL_checknumber(L, 2)),
        static_cast<int>(luaL_checknumber(L, 3)),
        static_cast<int>(luaL_checknumber(L, 4)),
    };
    current->hasDrawViewport = true;
    return 0;
}

int Host::l_DrawImage(lua_State* L) {
    if (!current || !current->renderer) {
        return 0;
    }
    float left = static_cast<float>(luaL_optnumber(L, 2, 0.0));
    float top = static_cast<float>(luaL_optnumber(L, 3, 0.0));
    float width = static_cast<float>(luaL_optnumber(L, 4, 0.0));
    float height = static_cast<float>(luaL_optnumber(L, 5, 0.0));
    if (width <= 0 || height <= 0) {
        return 0;
    }
    SDL_FRect rect{left, top, width, height};

    const bool requestedImage = lua_istable(L, 1);
    NativeImage* image = imageFromLua(L, 1);
    if (image && image->texture) {
        SDL_FRect src{};
        bool hasSrc = false;
        const int top = lua_gettop(L);
        if (top >= 9 && !lua_isnil(L, 6)) {
            // Legacy 4-coord call: handle, dx, dy, dw, dh, tcL, tcT, tcR, tcB.
            float tcLeft = static_cast<float>(luaL_optnumber(L, 6, 0.0));
            float tcTop = static_cast<float>(luaL_optnumber(L, 7, 0.0));
            float tcRight = static_cast<float>(luaL_optnumber(L, 8, 1.0));
            float tcBottom = static_cast<float>(luaL_optnumber(L, 9, 1.0));
            if (sourceRectForImage(image, tcLeft, tcTop, tcRight, tcBottom, src)) {
                hasSrc = true;
            }
        } else if (image->stackedAtlas && top >= 6 && lua_isnumber(L, 6)) {
            // PoE 0.5+ tree convention: a single trailing argument is the
            // 1-based array-layer/cell index into a stacked-atlas texture.
            const float tcLeft = static_cast<float>(lua_tonumber(L, 6));
            if (sourceRectForImage(image, tcLeft, 0.0f, 1.0f, 1.0f, src)) {
                hasSrc = true;
            }
        }
        DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Texture);
        cmd.rect = rect;
        cmd.texture = image->texture;
        cmd.hasSrc = hasSrc;
        cmd.src = src;
        return 0;
    }
    if (requestedImage) {
        return 0;
    }

    DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Rect);
    cmd.rect = rect;
    return 0;
}

int Host::l_DrawImageQuad(lua_State* L) {
    if (!current || !current->renderer) {
        return 0;
    }

    SDL_Vertex vertices[4]{};
    for (int i = 0; i < 4; ++i) {
        vertices[i].position.x = static_cast<float>(luaL_optnumber(L, 2 + i * 2, 0.0));
        vertices[i].position.y = static_cast<float>(luaL_optnumber(L, 3 + i * 2, 0.0));
        vertices[i].color = current->drawColor;
    }
    const bool requestedImage = lua_istable(L, 1);
    NativeImage* image = imageFromLua(L, 1);
    const int qtop = lua_gettop(L);
    bool drewTextured = false;
    if (image && image->texture && qtop >= 16) {
        float s1 = static_cast<float>(luaL_optnumber(L, 10, 0.0));
        float t1 = static_cast<float>(luaL_optnumber(L, 11, 0.0));
        float s2 = static_cast<float>(luaL_optnumber(L, 12, 0.0));
        float t2 = static_cast<float>(luaL_optnumber(L, 13, 0.0));
        float s3 = static_cast<float>(luaL_optnumber(L, 14, 0.0));
        float t3 = static_cast<float>(luaL_optnumber(L, 15, 0.0));
        float s4 = static_cast<float>(luaL_optnumber(L, 16, 0.0));
        float t4 = static_cast<float>(luaL_optnumber(L, 17, 0.0));
        if (image->stackedAtlas && isStackIndexQuadDraw(s1, t1, s2, t2, s3, t3, s4, t4)) {
            stackIndexTexCoords(image, s1, s1, t1, s2, t2, s3, t3, s4, t4);
        }
        vertices[0].tex_coord.x = s1;
        vertices[0].tex_coord.y = t1;
        vertices[1].tex_coord.x = s2;
        vertices[1].tex_coord.y = t2;
        vertices[2].tex_coord.x = s3;
        vertices[2].tex_coord.y = t3;
        vertices[3].tex_coord.x = s4;
        vertices[3].tex_coord.y = t4;
        DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Geometry);
        std::memcpy(cmd.verts, vertices, sizeof(vertices));
        cmd.texture = image->texture;
        cmd.geomTextured = true;
        drewTextured = true;
    } else if (image && image->texture && image->stackedAtlas && qtop >= 10 && lua_isnumber(L, 10)) {
        // PoE 0.5+ tree convention: handle, 8 vertex coords, 1-based array index.
        float s1, t1, s2, t2, s3, t3, s4, t4;
        const float idx = static_cast<float>(lua_tonumber(L, 10));
        stackIndexTexCoords(image, idx, s1, t1, s2, t2, s3, t3, s4, t4);
        vertices[0].tex_coord.x = s1; vertices[0].tex_coord.y = t1;
        vertices[1].tex_coord.x = s2; vertices[1].tex_coord.y = t2;
        vertices[2].tex_coord.x = s3; vertices[2].tex_coord.y = t3;
        vertices[3].tex_coord.x = s4; vertices[3].tex_coord.y = t4;
        DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Geometry);
        std::memcpy(cmd.verts, vertices, sizeof(vertices));
        cmd.texture = image->texture;
        cmd.geomTextured = true;
        drewTextured = true;
    }
    if (!drewTextured && !requestedImage) {
        DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Geometry);
        std::memcpy(cmd.verts, vertices, sizeof(vertices));
        cmd.geomTextured = false;
    }
    return 0;
}

int Host::l_DrawString(lua_State* L) {
    if (!current) {
        return 0;
    }
    float left = static_cast<float>(luaL_optnumber(L, 1, 0.0));
    float top = static_cast<float>(luaL_optnumber(L, 2, 0.0));
    std::string align = luaL_optstring(L, 3, "LEFT");
    double height = luaL_optnumber(L, 4, 12.0);
    std::string text = lua_gettop(L) >= 6 ? luaString(L, 6) : "";
    std::string font = luaL_optstring(L, 5, "VAR");

    DrawCommand& cmd = current->newDrawCommand(DrawCommand::Type::Text);
    cmd.tx = left;
    cmd.ty = top;
    cmd.align = std::move(align);
    cmd.height = height;
    cmd.font = std::move(font);
    cmd.text = std::move(text);
    return 0;
}

int Host::l_DrawStringWidth(lua_State* L) {
    double height = luaL_optnumber(L, 1, 12.0);
    std::string font = luaL_optstring(L, 2, "VAR");
    std::string text = lua_gettop(L) >= 3 ? luaString(L, 3) : "";
    if (current) {
        // Text is rendered at height*scale (physical pixels). Report the width in
        // virtual units that the rendered text actually occupies, so PoB's layout
        // (which sizes boxes to DrawStringWidth) matches the on-screen text and
        // doesn't clip the last characters.
        double scale = current->displayScale();
        double width = current->fontRenderer.stringWidth(height * scale, font, stripEscapes(text));
        lua_pushnumber(L, scale > 0.0 ? width / scale : width);
    } else {
        lua_pushnumber(L, 0);
    }
    return 1;
}

int Host::l_DrawStringCursorIndex(lua_State* L) {
    double height = luaL_optnumber(L, 1, 12.0);
    std::string font = luaL_optstring(L, 2, "VAR");
    std::string text = lua_gettop(L) >= 3 ? luaString(L, 3) : "";
    int curX = static_cast<int>(luaL_optnumber(L, 4, 0.0));
    int curY = static_cast<int>(luaL_optnumber(L, 5, 0.0));
    if (current) {
        // Match the scaled rendering: the cursor position is in virtual coords, so
        // scale it (and the font height) to the physical space the glyphs occupy.
        double scale = current->displayScale();
        lua_pushinteger(L, current->fontRenderer.stringCursorIndex(
            height * scale, font, text,
            static_cast<int>(curX * scale), static_cast<int>(curY * scale)));
    } else {
        lua_pushinteger(L, 0);
    }
    return 1;
}

int Host::l_StripEscapes(lua_State* L) {
    pushString(L, stripEscapes(luaString(L, 1)));
    return 1;
}

int Host::l_NewImageHandle(lua_State* L) {
    lua_newtable(L);
    lua_pushboolean(L, 0);
    lua_setfield(L, -2, "valid");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        NativeImage* existing = imageFromLua(L, 1);
        if (existing && existing->texture) {
            SDL_DestroyTexture(existing->texture);
            delete existing;
            lua_pushnil(L);
            lua_setfield(L, 1, "__native");
        }

        std::string fileName = luaString(L, 2);
        NativeImage* image = current ? loadNativeImage(L, current->renderer, fileName) : nullptr;
        if (image) {
            lua_pushlightuserdata(L, image);
            lua_setfield(L, 1, "__native");
        } else {
            std::fprintf(stderr, "Failed to load image: %s\n", fileName.c_str());
        }
        lua_pushboolean(L, image != nullptr);
        lua_setfield(L, 1, "valid");
        return 0;
    });
    lua_setfield(L, -2, "Load");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        NativeImage* existing = imageFromLua(L, 1);
        if (existing && existing->texture) {
            SDL_DestroyTexture(existing->texture);
            delete existing;
        }
        lua_pushnil(L);
        lua_setfield(L, 1, "__native");
        lua_pushboolean(L, 0);
        lua_setfield(L, 1, "valid");
        return 0;
    });
    lua_setfield(L, -2, "Unload");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_getfield(L, 1, "valid");
        return 1;
    });
    lua_setfield(L, -2, "IsValid");

    lua_pushcfunction(L, [](lua_State* L) -> int { return 0; });
    lua_setfield(L, -2, "SetLoadingPriority");

    lua_pushcfunction(L, [](lua_State* L) -> int {
        NativeImage* image = imageFromLua(L, 1);
        lua_pushinteger(L, image ? image->width : 1);
        lua_pushinteger(L, image ? image->height : 1);
        return 2;
    });
    lua_setfield(L, -2, "ImageSize");
    return 1;
}

int Host::l_SetCallback(lua_State* L) {
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_getfield(L, LUA_REGISTRYINDEX, kCallbacks);
    lua_pushvalue(L, 2);
    lua_setfield(L, -2, luaL_checkstring(L, 1));
    lua_pop(L, 1);
    return 0;
}

int Host::l_GetCallback(lua_State* L) {
    lua_getfield(L, LUA_REGISTRYINDEX, kCallbacks);
    lua_getfield(L, -1, luaL_checkstring(L, 1));
    return 1;
}

int Host::l_GetCursorPos(lua_State* L) {
    if (current) {
        SDL_GetMouseState(&current->mouseX, &current->mouseY);
        lua_pushnumber(L, current->mouseX);
        lua_pushnumber(L, current->mouseY);
    } else {
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
    }
    return 2;
}

int Host::l_SetCursorPos(lua_State* L) {
    if (current && current->window) {
        SDL_WarpMouseInWindow(
            current->window,
            static_cast<float>(luaL_checknumber(L, 1)),
            static_cast<float>(luaL_checknumber(L, 2))
        );
    }
    return 0;
}

int Host::l_ShowCursor(lua_State* L) {
    if (lua_toboolean(L, 1)) {
        SDL_ShowCursor();
    } else {
        SDL_HideCursor();
    }
    return 0;
}

int Host::l_SetForeground(lua_State*) {
    if (current && current->window) {
        SDL_RaiseWindow(current->window);
    }
    @autoreleasepool {
        [NSApp activateIgnoringOtherApps:YES];
    }
    return 0;
}

int Host::l_IsKeyDown(lua_State* L) {
    if (current) {
        setModifierStates(current->keyState);
        std::string key = luaString(L, 1);
        lua_pushboolean(L, current->keyState.contains(key));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

int Host::l_GetAsyncCount(lua_State* L) {
    lua_pushinteger(L, current ? static_cast<lua_Integer>(current->subScriptManager.runningCount()) : 0);
    return 1;
}

int Host::l_Copy(lua_State* L) {
    SDL_SetClipboardText(luaL_checkstring(L, 1));
    return 0;
}

int Host::l_Paste(lua_State* L) {
    char* text = SDL_GetClipboardText();
    lua_pushstring(L, text ? text : "");
    SDL_free(text);
    return 1;
}

int Host::l_GetScriptPath(lua_State* L) {
    pushString(L, registryString(L, kScriptPath));
    return 1;
}

int Host::l_GetRuntimePath(lua_State* L) {
    pushString(L, registryString(L, kRuntimePath));
    return 1;
}

int Host::l_GetUserPath(lua_State* L) {
    std::string path = applicationSupportPath();
    if (path.empty()) {
        lua_pushnil(L);
        lua_pushliteral(L, "~/Library/Application Support");
        lua_pushliteral(L, "Unable to locate Application Support");
        return 3;
    }
    pushString(L, path);
    return 1;
}

int Host::l_GetWorkDir(lua_State* L) {
    pushString(L, fs::current_path().string());
    return 1;
}

int Host::l_SetWorkDir(lua_State* L) {
    fs::current_path(luaL_checkstring(L, 1));
    return 0;
}

int Host::l_MakeDir(lua_State* L) {
    std::error_code ec;
    fs::create_directories(luaL_checkstring(L, 1), ec);
    return 0;
}

int Host::l_RemoveDir(lua_State* L) {
    std::error_code ec;
    fs::remove_all(luaL_checkstring(L, 1), ec);
    return 0;
}

namespace {
constexpr const char* kFileSearchMeta = "PoB.FileSearch";

struct FileSearch {
    struct Entry {
        std::string name;
        double size = 0.0;
        double mtime = 0.0;
    };
    std::vector<Entry> entries;
    size_t index = 0;
};

// Case-insensitive glob match supporting '*' and '?', matching SimpleGraphic's
// Windows FindFirstFile semantics (case-insensitive, like macOS APFS default).
bool wildcardMatchCI(const std::string& pat, const std::string& str) {
    auto lower = [](char c) { return static_cast<char>(std::tolower(static_cast<unsigned char>(c))); };
    size_t s = 0, p = 0;
    size_t star = std::string::npos, ss = 0;
    while (s < str.size()) {
        if (p < pat.size() && (pat[p] == '?' || lower(pat[p]) == lower(str[s]))) {
            ++s; ++p;
        } else if (p < pat.size() && pat[p] == '*') {
            star = p++;
            ss = s;
        } else if (star != std::string::npos) {
            p = star + 1;
            s = ++ss;
        } else {
            return false;
        }
    }
    while (p < pat.size() && pat[p] == '*') {
        ++p;
    }
    return p == pat.size();
}

FileSearch* checkFileSearch(lua_State* L) {
    auto** ud = static_cast<FileSearch**>(luaL_checkudata(L, 1, kFileSearchMeta));
    return ud ? *ud : nullptr;
}
} // namespace

int Host::l_NewFileSearch(lua_State* L) {
    std::string spec = luaString(L, 1);
    bool findDirs = lua_toboolean(L, 2);

    fs::path specPath(spec);
    fs::path dir = specPath.parent_path();
    std::string pattern = specPath.filename().string();
    if (dir.empty()) {
        dir = ".";
    }

    auto search = std::make_unique<FileSearch>();
    std::error_code ec;
    if (fs::is_directory(dir, ec)) {
        for (fs::directory_iterator it(dir, ec), end; it != end && !ec; it.increment(ec)) {
            std::error_code ec2;
            bool isDir = it->is_directory(ec2);
            if (findDirs != isDir) {
                continue;
            }
            std::string name = it->path().filename().string();
            if (!wildcardMatchCI(pattern, name)) {
                continue;
            }
            FileSearch::Entry entry;
            entry.name = name;
            struct stat st {};
            if (stat(it->path().c_str(), &st) == 0) {
                entry.size = static_cast<double>(st.st_size);
                entry.mtime = static_cast<double>(st.st_mtime);
            }
            search->entries.push_back(std::move(entry));
        }
    }

    if (search->entries.empty()) {
        lua_pushnil(L);
        return 1;
    }

    std::sort(search->entries.begin(), search->entries.end(),
        [](const FileSearch::Entry& a, const FileSearch::Entry& b) { return a.name < b.name; });

    auto** ud = static_cast<FileSearch**>(lua_newuserdata(L, sizeof(FileSearch*)));
    *ud = search.release();

    if (luaL_newmetatable(L, kFileSearchMeta)) {
        lua_pushcfunction(L, [](lua_State* L) -> int {
            auto** p = static_cast<FileSearch**>(luaL_checkudata(L, 1, kFileSearchMeta));
            if (p && *p) {
                delete *p;
                *p = nullptr;
            }
            return 0;
        });
        lua_setfield(L, -2, "__gc");

        lua_newtable(L);
        lua_pushcfunction(L, [](lua_State* L) -> int {
            FileSearch* s = checkFileSearch(L);
            if (s && s->index < s->entries.size()) {
                lua_pushstring(L, s->entries[s->index].name.c_str());
            } else {
                lua_pushstring(L, "");
            }
            return 1;
        });
        lua_setfield(L, -2, "GetFileName");

        lua_pushcfunction(L, [](lua_State* L) -> int {
            FileSearch* s = checkFileSearch(L);
            lua_pushnumber(L, (s && s->index < s->entries.size()) ? s->entries[s->index].size : 0.0);
            return 1;
        });
        lua_setfield(L, -2, "GetFileSize");

        lua_pushcfunction(L, [](lua_State* L) -> int {
            FileSearch* s = checkFileSearch(L);
            lua_pushnumber(L, (s && s->index < s->entries.size()) ? s->entries[s->index].mtime : 0.0);
            return 1;
        });
        lua_setfield(L, -2, "GetFileModifiedTime");

        lua_pushcfunction(L, [](lua_State* L) -> int {
            FileSearch* s = checkFileSearch(L);
            if (s) {
                ++s->index;
                lua_pushboolean(L, s->index < s->entries.size());
            } else {
                lua_pushboolean(L, 0);
            }
            return 1;
        });
        lua_setfield(L, -2, "NextFile");

        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

int Host::l_OpenURL(lua_State* L) {
    @autoreleasepool {
        NSString* urlString = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];
        NSURL* url = [NSURL URLWithString:urlString];
        if (url) {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    }
    return 0;
}

int Host::l_SpawnProcess(lua_State* L) {
    std::string cmd = luaString(L, 1);
    if (lua_gettop(L) >= 2 && lua_isstring(L, 2)) {
        cmd += " ";
        cmd += luaString(L, 2);
    }
    std::system(cmd.c_str());
    return 0;
}

int Host::l_Deflate(lua_State* L) {
    size_t inputLen = 0;
    const char* input = lua_tolstring(L, 1, &inputLen);
    auto data = rawDeflate(input ? std::string(input, inputLen) : std::string());
    if (data.empty() && inputLen > 0) {
        lua_pushnil(L);
        lua_pushliteral(L, "Deflate failed");
        return 2;
    }
    lua_pushlstring(L, reinterpret_cast<const char*>(data.data()), data.size());
    return 1;
}

int Host::l_Inflate(lua_State* L) {
    size_t len = 0;
    const char* input = luaL_checklstring(L, 1, &len);
    auto data = rawInflate(std::string(input, len));
    if (data.empty() && len > 0) {
        lua_pushnil(L);
        lua_pushliteral(L, "Inflate failed");
        return 2;
    }
    lua_pushlstring(L, reinterpret_cast<const char*>(data.data()), data.size());
    return 1;
}

static int loadModuleImpl(lua_State* L, bool protectedMode) {
    std::string fileName = luaString(L, 1);
    if (!fileName.ends_with(".lua")) {
        fileName += ".lua";
    }
    int nargs = lua_gettop(L) - 1;
    if (luaL_loadfile(L, fileName.c_str()) != LUA_OK) {
        if (protectedMode) {
            return 1;
        }
        return lua_error(L);
    }
    lua_insert(L, 1);
    lua_remove(L, 2);
    if (lua_pcall(L, nargs, LUA_MULTRET, 0) != LUA_OK) {
        if (protectedMode) {
            return 1;
        }
        return lua_error(L);
    }
    if (protectedMode) {
        lua_pushnil(L);
        lua_insert(L, 1);
    }
    return lua_gettop(L);
}

int Host::l_LoadModule(lua_State* L) {
    return loadModuleImpl(L, false);
}

int Host::l_PLoadModule(lua_State* L) {
    return loadModuleImpl(L, true);
}

int Host::l_PCall(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int nargs = lua_gettop(L) - 1;
    if (lua_pcall(L, nargs, LUA_MULTRET, 0) != LUA_OK) {
        return 1;
    }
    lua_pushnil(L);
    lua_insert(L, 1);
    return lua_gettop(L);
}

int Host::l_ConPrintf(lua_State* L) {
    const char* fmt = luaL_checkstring(L, 1);
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "format");
    lua_pushvalue(L, 1);
    int nargs = lua_gettop(L) - 3;
    for (int i = 0; i < nargs; ++i) {
        lua_pushvalue(L, 2 + i);
    }
    if (lua_pcall(L, nargs + 1, 1, 0) == LUA_OK) {
        std::fprintf(stdout, "%s\n", lua_tostring(L, -1));
    } else {
        std::fprintf(stdout, "%s\n", fmt);
    }
    return 0;
}

int Host::l_ConExecute(lua_State*) { return 0; }
int Host::l_ConClear(lua_State*) { return 0; }

int Host::l_Restart(lua_State*) {
    return 0;
}

int Host::l_Exit(lua_State*) {
    if (current) {
        current->running = false;
    }
    return 0;
}

int Host::l_LaunchSubScript(lua_State* L) {
    if (!current) {
        lua_pushnil(L);
        return 1;
    }
    current->subScriptManager.launch(L);
    return 1;
}

int Host::l_AbortSubScript(lua_State* L) {
    if (current && lua_islightuserdata(L, 1)) {
        current->subScriptManager.abort(lua_touserdata(L, 1));
    }
    return 0;
}

int Host::l_IsSubScriptRunning(lua_State* L) {
    const bool running = current && lua_islightuserdata(L, 1) && current->subScriptManager.isRunning(lua_touserdata(L, 1));
    lua_pushboolean(L, running);
    return 1;
}
