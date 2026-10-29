@echo off
setlocal
cd /d "%~dp0"
if not defined VCToolsInstallDir (
  if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
  ) else (
    echo Please run from an x64 Visual Studio developer command prompt.
    exit /b 1
  )
)
cl /nologo /std:c++17 /EHsc /utf-8 /O2 tools\FontAtlas.cpp /Fe:tools\FontAtlas.exe /Fo:tools\FontAtlas.obj gdi32.lib user32.lib
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /utf-8 /O2 tools\LuaRunner.cpp /Fe:tools\LuaRunner.exe /Fo:tools\LuaRunner.obj
if errorlevel 1 exit /b 1
tools\FontAtlas.exe src\Locales\Fonts
if errorlevel 1 exit /b 1
echo Build completed. Run start.cmd to launch PoB2.
