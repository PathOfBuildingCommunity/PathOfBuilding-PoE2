// Minimal macOS launcher for Path of Building (PoE2).
//
// SimpleGraphic is a shared library exporting RunLuaFileAsWin(argc, argv),
// where argv[0] is the path to the entry Lua script. On Windows a small .exe
// plays this role; this is the macOS equivalent.
//
// The launcher is linked against libSimpleGraphic.dylib with an rpath of
// @executable_path, so the dylib is found next to this binary.
//
// Usage: pob2 [script.lua] [extra args...]
// Everything after the executable name is forwarded to SimpleGraphic, with
// the first argument used as the entry script (default "Launch.lua").

extern int RunLuaFileAsWin(int argc, char** argv);

int main(int argc, char** argv)
{
    if (argc > 1) {
        // Forward args verbatim: argv[1] becomes the script, rest are passed on.
        return RunLuaFileAsWin(argc - 1, argv + 1);
    }
    char* def[1] = { "Launch.lua" };
    return RunLuaFileAsWin(1, def);
}
