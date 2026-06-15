#pragma once

#include "FontRenderer.hpp"
#include "SubScript.hpp"

#include <SDL3/SDL.h>
#include <string>
#include <unordered_set>
#include <vector>

struct lua_State;

// A single deferred draw operation. PoB issues draw calls in arbitrary order and
// relies on SetDrawLayer/sub-layer to control z-ordering (tooltips, popups and
// dropdowns draw on high layers so they appear on top). We record every draw and
// replay them sorted by (layer, subLayer, sequence) at the end of the frame.
struct DrawCommand {
    enum class Type { Rect, Texture, Geometry, Text };
    int layer = 0;
    int subLayer = 0;
    unsigned long long seq = 0;
    Type type = Type::Rect;
    bool hasViewport = false;
    SDL_Rect viewport{};
    SDL_FColor color{1.0f, 1.0f, 1.0f, 1.0f};
    SDL_FRect rect{};
    SDL_Texture* texture = nullptr;
    bool hasSrc = false;
    SDL_FRect src{};
    SDL_Vertex verts[4]{};
    bool geomTextured = false;
    std::string text;
    std::string font;
    std::string align;
    double height = 0.0;
    float tx = 0.0f;
    float ty = 0.0f;
};

class Host {
public:
    Host();
    ~Host();

    bool init(int argc, char** argv);
    int run();

private:
    static Host* current;

    lua_State* L = nullptr;
    SDL_Window* window = nullptr;
    SDL_Renderer* renderer = nullptr;
    bool running = true;
    double dpiScaleOverride = 0.0;
    SDL_FColor drawColor = {1.0f, 1.0f, 1.0f, 1.0f};
    float mouseX = 0.0f;
    float mouseY = 0.0f;
    std::unordered_set<std::string> keyState;
    FontRenderer fontRenderer;
    SubScriptManager subScriptManager;

    int drawLayer = 0;
    int drawSubLayer = 0;
    unsigned long long drawSeq = 0;
    bool hasDrawViewport = false;
    SDL_Rect drawViewport{};
    std::vector<DrawCommand> drawCommands;

    bool initLua(int argc, char** argv);
    bool loadLaunchScript();
    void registerApi();
    void registerPreloadModules();
    void pumpEvents();
    void beginFrameDraw();
    void flushDrawCommands();
    DrawCommand& newDrawCommand(DrawCommand::Type type);
    void executeTextCommand(const DrawCommand& cmd, float scale);
    // The factor mapping PoB's virtual (point) coordinates to physical pixels,
    // i.e. the display's pixel density combined with any UI scaling override.
    // 1.0 on a standard display, 2.0 on a typical Retina display.
    double displayScale() const;
    void callMainObject(const char* method);
    void callMainObjectKey(const char* method, const std::string& key, bool doubleClick = false);
    void updateLogicalPresentation();
    void setSearchPaths();

    static int l_SetMainObject(lua_State* L);
    static int l_GetTime(lua_State* L);
    static int l_SetWindowTitle(lua_State* L);
    static int l_RenderInit(lua_State* L);
    static int l_GetScreenSize(lua_State* L);
    static int l_GetScreenScale(lua_State* L);
    static int l_GetVirtualScreenSize(lua_State* L);
    static int l_GetDPIScaleOverridePercent(lua_State* L);
    static int l_SetDPIScaleOverridePercent(lua_State* L);
    static int l_SetDrawColor(lua_State* L);
    static int l_GetDrawColor(lua_State* L);
    static int l_SetDrawLayer(lua_State* L);
    static int l_SetViewport(lua_State* L);
    static int l_DrawImage(lua_State* L);
    static int l_DrawImageQuad(lua_State* L);
    static int l_DrawString(lua_State* L);
    static int l_DrawStringWidth(lua_State* L);
    static int l_DrawStringCursorIndex(lua_State* L);
    static int l_StripEscapes(lua_State* L);
    static int l_NewImageHandle(lua_State* L);
    static int l_SetCallback(lua_State* L);
    static int l_GetCallback(lua_State* L);
    static int l_GetCursorPos(lua_State* L);
    static int l_SetCursorPos(lua_State* L);
    static int l_ShowCursor(lua_State* L);
    static int l_SetForeground(lua_State* L);
    static int l_IsKeyDown(lua_State* L);
    static int l_GetAsyncCount(lua_State* L);
    static int l_Copy(lua_State* L);
    static int l_Paste(lua_State* L);
    static int l_GetScriptPath(lua_State* L);
    static int l_GetRuntimePath(lua_State* L);
    static int l_GetUserPath(lua_State* L);
    static int l_GetWorkDir(lua_State* L);
    static int l_SetWorkDir(lua_State* L);
    static int l_MakeDir(lua_State* L);
    static int l_RemoveDir(lua_State* L);
    static int l_NewFileSearch(lua_State* L);
    static int l_OpenURL(lua_State* L);
    static int l_SpawnProcess(lua_State* L);
    static int l_Deflate(lua_State* L);
    static int l_Inflate(lua_State* L);
    static int l_LoadModule(lua_State* L);
    static int l_PLoadModule(lua_State* L);
    static int l_PCall(lua_State* L);
    static int l_ConPrintf(lua_State* L);
    static int l_ConExecute(lua_State* L);
    static int l_ConClear(lua_State* L);
    static int l_Restart(lua_State* L);
    static int l_Exit(lua_State* L);
    static int l_LaunchSubScript(lua_State* L);
    static int l_AbortSubScript(lua_State* L);
    static int l_IsSubScriptRunning(lua_State* L);
};
