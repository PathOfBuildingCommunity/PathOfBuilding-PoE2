#include "SubScript.hpp"

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

#include <condition_variable>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {
// Must be a string key, NOT an integer index. Registry index 0 is FREELIST_REF,
// used internally by luaL_ref/luaL_unref; lcurl's write/header callbacks ref/unref
// in the registry and would clobber an integer-keyed worker pointer, leaving
// fromState() returning a garbage/NULL SubScriptWorker.
constexpr const char* kSubScriptRegistryKey = "__pob_subscript_worker";

enum class ValueType { Nil, Boolean, Number, String };

struct ValueNode {
    ValueType type = ValueType::Nil;
    bool boolean = false;
    double number = 0.0;
    std::string string;
    std::unique_ptr<ValueNode> next;
};

struct PendingCall {
    std::string name;
    std::unique_ptr<ValueNode> args;
    std::unique_ptr<PendingCall> next;
};

void wipeValues(ValueNode* node) {
    while (node) {
        node = node->next.release();
    }
}

std::unique_ptr<ValueNode> buildValues(lua_State* L, int startIndex) {
    std::unique_ptr<ValueNode> head;
    ValueNode* tail = nullptr;
    const int top = lua_gettop(L);
    for (int i = startIndex; i <= top; ++i) {
        auto node = std::make_unique<ValueNode>();
        switch (lua_type(L, i)) {
            case LUA_TBOOLEAN:
                node->type = ValueType::Boolean;
                node->boolean = lua_toboolean(L, i) != 0;
                break;
            case LUA_TNUMBER:
                node->type = ValueType::Number;
                node->number = lua_tonumber(L, i);
                break;
            case LUA_TSTRING:
                node->type = ValueType::String;
                node->string = lua_tostring(L, i);
                break;
            default:
                node->type = ValueType::Nil;
                break;
        }
        if (tail) {
            tail->next = std::move(node);
            tail = tail->next.get();
        } else {
            head = std::move(node);
            tail = head.get();
        }
    }
    lua_settop(L, startIndex - 1);
    return head;
}

int pushValues(lua_State* L, ValueNode* node) {
    int count = 0;
    for (; node; node = node->next.get()) {
        switch (node->type) {
            case ValueType::Nil:
                lua_pushnil(L);
                break;
            case ValueType::Boolean:
                lua_pushboolean(L, node->boolean);
                break;
            case ValueType::Number:
                lua_pushnumber(L, node->number);
                break;
            case ValueType::String:
                lua_pushstring(L, node->string.c_str());
                break;
        }
        ++count;
    }
    return count;
}

bool pushValue(lua_State* L, const ValueNode& node) {
    switch (node.type) {
        case ValueType::Nil:
            lua_pushnil(L);
            break;
        case ValueType::Boolean:
            lua_pushboolean(L, node.boolean);
            break;
        case ValueType::Number:
            lua_pushnumber(L, node.number);
            break;
        case ValueType::String:
            lua_pushstring(L, node.string.c_str());
            break;
    }
    return true;
}

struct SubScriptWorker {
    size_t slot = 0;
    lua_State* L = nullptr;
    std::thread worker;

    std::mutex mutex;
    std::condition_variable cv;

    bool running = false;
    bool finished = false;
    bool funcWaiting = false;
    bool subWriting = false;
    std::string errorStr;

    PendingCall* subCalls = nullptr;
    PendingCall funcCall;
    std::unique_ptr<ValueNode> funcReturns;

    ~SubScriptWorker() {
        stopWorker();
        if (L) {
            lua_close(L);
            L = nullptr;
        }
    }

    static int traceback(lua_State* L) {
        if (!lua_isstring(L, 1)) {
            return 1;
        }
        lua_getglobal(L, "debug");
        if (!lua_istable(L, -1)) {
            lua_pop(L, 1);
            return 1;
        }
        lua_getfield(L, -1, "traceback");
        if (!lua_isfunction(L, -1)) {
            lua_pop(L, 2);
            return 1;
        }
        lua_pushvalue(L, 1);
        lua_pushinteger(L, 2);
        lua_call(L, 2, 1);
        return 1;
    }

    static int panic(lua_State* L) {
        std::fprintf(stderr, "SubScript panic: %s\n", lua_tostring(L, -1));
        return 0;
    }

    static SubScriptWorker* fromState(lua_State* L) {
        lua_getfield(L, LUA_REGISTRYINDEX, kSubScriptRegistryKey);
        auto* ss = static_cast<SubScriptWorker*>(lua_touserdata(L, -1));
        lua_pop(L, 1);
        return ss;
    }

    static void parseList(lua_State* L, const char* list, lua_CFunction fn) {
        if (!list || !*list) {
            return;
        }
        std::string copy(list);
        char* buffer = copy.data();
        char* token = std::strtok(buffer, ",");
        while (token) {
            while (*token == ' ') {
                ++token;
            }
            if (*token) {
                lua_pushstring(L, token);
                lua_pushcclosure(L, fn, 1);
                lua_setglobal(L, token);
            }
            token = std::strtok(nullptr, ",");
        }
    }

    static int subScriptFunc(lua_State* L) {
        auto* ss = fromState(L);
        const char* name = lua_tostring(L, lua_upvalueindex(1));
        std::unique_lock lock(ss->mutex);
        ss->funcCall.name = name ? name : "";
        ss->funcCall.args = buildValues(L, 1);
        ss->funcReturns.reset();
        ss->funcWaiting = true;
        ss->cv.notify_all();
        ss->cv.wait(lock, [&] { return !ss->funcWaiting || !ss->running; });
        lock.unlock();
        return pushValues(L, ss->funcReturns.get());
    }

    static int subScriptSub(lua_State* L) {
        auto* ss = fromState(L);
        const char* name = lua_tostring(L, lua_upvalueindex(1));
        auto call = std::make_unique<PendingCall>();
        call->name = name ? name : "";
        call->args = buildValues(L, 1);

        std::lock_guard lock(ss->mutex);
        ss->subWriting = true;
        call->next.reset(ss->subCalls);
        ss->subCalls = call.release();
        ss->subWriting = false;
        ss->cv.notify_all();
        return 0;
    }

    static int osExit(lua_State*) {
        return 0;
    }

    static void copyPreloadModules(lua_State* mainL, lua_State* subL) {
        // package.preload entries registered by the host are plain C functions.
        // Copy them across states by their C function pointer. Cross-state copies
        // must read the value out of mainL and re-push it onto subL; the previous
        // implementation pushed onto mainL while calling lua_settable on subL,
        // which corrupted mainL's stack on every subscript launch.
        lua_getglobal(subL, "package");      // subL: [package]
        lua_getfield(subL, -1, "preload");    // subL: [package, preload]
        lua_getglobal(mainL, "package");      // mainL: [package]
        lua_getfield(mainL, -1, "preload");   // mainL: [package, preload]
        lua_pushnil(mainL);                   // mainL: [package, preload, nil]
        while (lua_next(mainL, -2) != 0) {    // mainL: [package, preload, key, value]
            if (lua_type(mainL, -2) == LUA_TSTRING && lua_iscfunction(mainL, -1)) {
                const char* key = lua_tostring(mainL, -2);
                lua_CFunction fn = lua_tocfunction(mainL, -1);
                if (fn) {
                    lua_pushcfunction(subL, fn);  // subL: [package, preload, fn]
                    lua_setfield(subL, -2, key);  // subL: [package, preload]
                }
            }
            lua_pop(mainL, 1);                // mainL: [package, preload, key]
        }
        lua_pop(mainL, 2);                    // mainL: []
        lua_pop(subL, 2);                     // subL: []
    }

    static void hookStop(lua_State* L, lua_Debug*) {
        lua_pushstring(L, "aborted");
        lua_error(L);
    }

    void stopWorker() {
        if (worker.joinable()) {
            {
                std::lock_guard lock(mutex);
                if (running && L) {
                    lua_sethook(L, hookStop, LUA_MASKLINE, 0);
                }
            }
            worker.join();
        }
    }

    bool start(lua_State* mainState, const std::string& script, const char* funcList, const char* subList, std::unique_ptr<ValueNode> args) {
        L = luaL_newstate();
        if (!L) {
            return false;
        }
        lua_atpanic(L, panic);
        lua_pushlightuserdata(L, this);
        lua_setfield(L, LUA_REGISTRYINDEX, kSubScriptRegistryKey);
        lua_pushcfunction(L, traceback);

        lua_gc(L, LUA_GCSTOP, 0);
        luaL_openlibs(L);
        lua_getglobal(L, "os");
        lua_pushcfunction(L, osExit);
        lua_setfield(L, -2, "exit");
        lua_pop(L, 1);
        copyPreloadModules(mainState, L);
        parseList(L, funcList, subScriptFunc);
        parseList(L, subList, subScriptSub);
        lua_gc(L, LUA_GCRESTART, -1);

        if (luaL_loadstring(L, script.c_str()) != LUA_OK) {
            std::fprintf(stderr, "SubScript load error: %s\n", lua_tostring(L, -1));
            lua_close(L);
            L = nullptr;
            return false;
        }

        const int argCount = pushValues(L, args.get());
        running = true;
        worker = std::thread([this, argCount] {
            if (lua_pcall(L, argCount, LUA_MULTRET, 1) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                if (err) {
                    std::lock_guard lock(mutex);
                    errorStr = err;
                }
            }
            std::lock_guard lock(mutex);
            finished = true;
            running = false;
            cv.notify_all();
        });
        return true;
    }

    static bool invokeMain(lua_State* mainL, const char* mainObjectKey, const char* method, int args, int results) {
        lua_getfield(mainL, LUA_REGISTRYINDEX, mainObjectKey);
        if (!lua_istable(mainL, -1)) {
            lua_pop(mainL, 1);
            return false;
        }
        lua_getfield(mainL, -1, method);
        if (!lua_isfunction(mainL, -1)) {
            lua_pop(mainL, 2);
            return false;
        }
        lua_insert(mainL, -(args + 2));
        if (lua_pcall(mainL, args + 1, results, 0) != LUA_OK) {
            std::fprintf(stderr, "SubScript %s error: %s\n", method, lua_tostring(mainL, -1));
            lua_settop(mainL, 0);
            return false;
        }
        return true;
    }

    void processFrame(lua_State* mainL, const char* mainObjectKey) {
        PendingCall* asyncCalls = nullptr;
        bool handleFinish = false;
        bool handleFunc = false;
        PendingCall funcSnapshot;
        funcSnapshot.name = funcCall.name;

        {
            std::unique_lock lock(mutex);
            while (subWriting) {
                lock.unlock();
                std::this_thread::yield();
                lock.lock();
            }
            asyncCalls = subCalls;
            subCalls = nullptr;
            handleFunc = funcWaiting;
            if (handleFunc) {
                funcSnapshot.args = std::move(funcCall.args);
            }
            handleFinish = finished;
        }

        while (asyncCalls) {
            PendingCall* call = asyncCalls;
            asyncCalls = call->next.release();
            lua_settop(mainL, 0);
            lua_getfield(mainL, LUA_REGISTRYINDEX, mainObjectKey);
            lua_getfield(mainL, -1, "OnSubCall");
            lua_insert(mainL, -2);
            lua_pushstring(mainL, call->name.c_str());
            const int argCount = pushValues(mainL, call->args.get()) + 2;
            if (lua_pcall(mainL, argCount, 0, 0) != LUA_OK) {
                std::fprintf(stderr, "OnSubCall(%s) error: %s\n", call->name.c_str(), lua_tostring(mainL, -1));
            }
            lua_settop(mainL, 0);
            wipeValues(call->args.release());
            delete call;
        }

        if (handleFunc) {
            lua_settop(mainL, 0);
            lua_getfield(mainL, LUA_REGISTRYINDEX, mainObjectKey);
            lua_getfield(mainL, -1, "OnSubCall");
            lua_insert(mainL, -2);
            lua_pushstring(mainL, funcSnapshot.name.c_str());
            const int argCount = pushValues(mainL, funcSnapshot.args.get()) + 2;
            std::unique_ptr<ValueNode> returns;
            if (lua_pcall(mainL, argCount, LUA_MULTRET, 0) == LUA_OK) {
                const int top = lua_gettop(mainL);
                if (top > 0) {
                    returns = buildValues(mainL, 1);
                }
            } else {
                std::fprintf(stderr, "OnSubCall(%s) error: %s\n", funcSnapshot.name.c_str(), lua_tostring(mainL, -1));
            }
            lua_settop(mainL, 0);
            wipeValues(funcSnapshot.args.release());

            std::lock_guard lock(mutex);
            funcReturns = std::move(returns);
            funcWaiting = false;
            cv.notify_all();
        }

        if (handleFinish) {
            std::string errCopy;
            std::vector<ValueNode> returnValues;
            {
                std::lock_guard lock(mutex);
                errCopy = errorStr;
                errorStr.clear();
                finished = false;
                if (L && errCopy.empty()) {
                    const int top = lua_gettop(L);
                    for (int i = 2; i <= top; ++i) {
                        ValueNode node;
                        switch (lua_type(L, i)) {
                            case LUA_TBOOLEAN:
                                node.type = ValueType::Boolean;
                                node.boolean = lua_toboolean(L, i) != 0;
                                break;
                            case LUA_TNUMBER:
                                node.type = ValueType::Number;
                                node.number = lua_tonumber(L, i);
                                break;
                            case LUA_TSTRING:
                                node.type = ValueType::String;
                                node.string = lua_tostring(L, i);
                                break;
                            default:
                                node.type = ValueType::Nil;
                                break;
                        }
                        returnValues.push_back(std::move(node));
                    }
                }
            }

            lua_settop(mainL, 0);
            if (!errCopy.empty()) {
                lua_getfield(mainL, LUA_REGISTRYINDEX, mainObjectKey);
                lua_getfield(mainL, -1, "OnSubError");
                lua_insert(mainL, -2);
                lua_pushlightuserdata(mainL, reinterpret_cast<void*>(slot));
                lua_pushstring(mainL, errCopy.c_str());
                if (lua_pcall(mainL, 3, 0, 0) != LUA_OK) {
                    std::fprintf(stderr, "OnSubError error: %s\n", lua_tostring(mainL, -1));
                }
            } else {
                lua_getfield(mainL, LUA_REGISTRYINDEX, mainObjectKey);
                lua_getfield(mainL, -1, "OnSubFinished");
                lua_insert(mainL, -2);
                lua_pushlightuserdata(mainL, reinterpret_cast<void*>(slot));
                for (const auto& value : returnValues) {
                    pushValue(mainL, value);
                }
                const int argCount = static_cast<int>(returnValues.size()) + 2;
                if (lua_pcall(mainL, argCount, 0, 0) != LUA_OK) {
                    std::fprintf(stderr, "OnSubFinished error: %s\n", lua_tostring(mainL, -1));
                }
            }
            lua_settop(mainL, 0);
        }
    }

    bool isComplete() const {
        return !running && !finished && !worker.joinable();
    }
};
}

struct SubScriptManager::Impl {
    std::vector<std::unique_ptr<SubScriptWorker>> scripts;

    SubScriptWorker* find(void* id) {
        const size_t slot = reinterpret_cast<size_t>(id);
        if (slot >= scripts.size() || !scripts[slot]) {
            return nullptr;
        }
        return scripts[slot].get();
    }

    size_t allocateSlot() {
        for (size_t i = 0; i < scripts.size(); ++i) {
            if (!scripts[i]) {
                return i;
            }
        }
        return scripts.size();
    }
};

void SubScriptManager::shutdown() {
    if (!impl) {
        return;
    }
    for (auto& script : impl->scripts) {
        if (script) {
            script->stopWorker();
        }
    }
    impl->scripts.clear();
    delete impl;
    impl = nullptr;
}

void SubScriptManager::processFrame(lua_State* mainL, const char* mainObjectKey) {
    if (!impl) {
        return;
    }
    for (size_t i = 0; i < impl->scripts.size(); ++i) {
        // The worker object lives on the heap and is stable, but the vector
        // storage is not: a Lua callback dispatched inside processFrame() (e.g.
        // OnSubFinished launching another download) can call launch(), which may
        // emplace_back() and reallocate impl->scripts. Capture the worker by
        // pointer and re-index afterwards instead of holding a vector reference.
        SubScriptWorker* worker = impl->scripts[i] ? impl->scripts[i].get() : nullptr;
        if (!worker) {
            continue;
        }
        worker->processFrame(mainL, mainObjectKey);
        if (i < impl->scripts.size() && impl->scripts[i].get() == worker &&
            !worker->running && !worker->finished) {
            worker->stopWorker();
            impl->scripts[i].reset();
        }
    }
}

void* SubScriptManager::launch(lua_State* mainL) {
    const int argc = lua_gettop(mainL);
    if (argc < 3 || !lua_isstring(mainL, 1) || !lua_isstring(mainL, 2) || !lua_isstring(mainL, 3)) {
        lua_pushnil(mainL);
        return nullptr;
    }
    for (int i = 4; i <= argc; ++i) {
        if (!lua_isnil(mainL, i) && !lua_isboolean(mainL, i) && !lua_isnumber(mainL, i) && !lua_isstring(mainL, i)) {
            lua_pushnil(mainL);
            return nullptr;
        }
    }

    if (!impl) {
        impl = new Impl();
    }

    const size_t slot = impl->allocateSlot();
    if (slot >= impl->scripts.size()) {
        impl->scripts.emplace_back();
    }

    auto script = std::make_unique<SubScriptWorker>();
    script->slot = slot;
    auto args = buildValues(mainL, 4);
    const std::string scriptText = lua_tostring(mainL, 1);
    const char* funcList = lua_tostring(mainL, 2);
    const char* subList = lua_tostring(mainL, 3);

    if (!script->start(mainL, scriptText, funcList, subList, std::move(args))) {
        lua_pushnil(mainL);
        return nullptr;
    }

    impl->scripts[slot] = std::move(script);
    lua_pushlightuserdata(mainL, reinterpret_cast<void*>(slot));
    return reinterpret_cast<void*>(slot);
}

void SubScriptManager::abort(void* id) {
    if (!impl) {
        return;
    }
    const size_t slot = reinterpret_cast<size_t>(id);
    if (slot < impl->scripts.size() && impl->scripts[slot]) {
        impl->scripts[slot]->stopWorker();
        impl->scripts[slot].reset();
    }
}

bool SubScriptManager::isRunning(void* id) const {
    if (!impl) {
        return false;
    }
    if (SubScriptWorker* script = impl->find(id)) {
        return script->running;
    }
    return false;
}

size_t SubScriptManager::runningCount() const {
    if (!impl) {
        return 0;
    }
    size_t count = 0;
    for (const auto& script : impl->scripts) {
        if (script && script->running) {
            ++count;
        }
    }
    return count;
}
