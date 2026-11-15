// 使用官方运行时的 LuaJIT 执行测试，保持与实际应用相同的 Lua ABI。
#define NOMINMAX
#include <windows.h>
#include <filesystem>
#include <iostream>
#include <stdexcept>

namespace {
struct lua_State;
HMODULE library;

// 缺少运行时符号时停止，避免调用空指针。
template<class T> T Symbol(const char* name) {
    auto pointer = GetProcAddress(library, name);
    if (!pointer) throw std::runtime_error(name);
    return reinterpret_cast<T>(pointer);
}
}

/// <summary>在官方 LuaJIT 中运行指定脚本并返回错误码。</summary>
int main(int argc, char** argv) {
    if (argc != 2) { std::cerr << "Usage: LuaRunner <script.lua>\n"; return 1; }
    try {
        wchar_t exe[MAX_PATH]; GetModuleFileNameW(nullptr, exe, MAX_PATH);
        auto runtime = std::filesystem::path(exe).parent_path().parent_path() / L"runtime";
        SetDllDirectoryW(runtime.c_str());
        library = LoadLibraryW((runtime / L"lua51.dll").c_str());
        if (!library) throw std::runtime_error("Unable to load official runtime/lua51.dll");
        auto create = Symbol<lua_State*(*)()>("luaL_newstate");
        auto open = Symbol<void(*)(lua_State*)>("luaL_openlibs");
        auto load = Symbol<int(*)(lua_State*, const char*)>("luaL_loadfile");
        auto call = Symbol<int(*)(lua_State*, int, int, int)>("lua_pcall");
        auto str = Symbol<const char*(*)(lua_State*, int, size_t*)>("lua_tolstring");
        auto close = Symbol<void(*)(lua_State*)>("lua_close");
        lua_State* state = create(); open(state);
        int result = load(state, argv[1]);
        if (!result) result = call(state, 0, -1, 0);
        if (result) std::cerr << str(state, -1, nullptr) << '\n';
        close(state); FreeLibrary(library);
        return result ? 1 : 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
