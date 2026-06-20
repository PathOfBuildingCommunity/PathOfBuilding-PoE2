#pragma once

#include <cstddef>

struct lua_State;

class SubScriptManager {
public:
    void shutdown();
    void processFrame(lua_State* mainL, const char* mainObjectKey);

    // LaunchSubScript implementation; reads arguments from mainL stack.
    void* launch(lua_State* mainL);
    void abort(void* id);
    bool isRunning(void* id) const;
    size_t runningCount() const;

private:
    struct Impl;
    Impl* impl = nullptr;
};
