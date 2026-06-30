-- Standalone harness: luajit run_translate.lua <data.lua> <translator.lua> <fixture.txt>
_G.__CN_TRANSLATION_DATA = dofile(arg[1])
local M = dofile(arg[2])
local f = assert(io.open(arg[3], "rb"))
local raw = f:read("*a"); f:close()
io.write("===== TRANSLATED =====\n")
io.write(M.translate(raw))
io.write("\n===== END =====\n")
