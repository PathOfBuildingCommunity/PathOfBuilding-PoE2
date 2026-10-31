@echo off
setlocal
cd /d "%~dp0"
if not "%~1"=="" if not "%~1"=="--all-fonts" (
  echo Usage: build.cmd [--all-fonts]
  exit /b 1
)
if not defined VCToolsInstallDir (
  for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    call "%%i\VC\Auxiliary\Build\vcvars64.bat" >nul
  )
)
if not defined VCToolsInstallDir (
  echo Please install the Visual Studio x64 C++ build tools or use a developer command prompt.
  exit /b 1
)
cl /nologo /std:c++17 /EHsc /utf-8 /O2 tools\FontAtlas.cpp /Fe:tools\FontAtlas.exe /Fo:tools\FontAtlas.obj gdi32.lib user32.lib
if errorlevel 1 exit /b 1
copy /Y tools\FontAtlas.exe runtime\FontAtlas.exe >nul
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /utf-8 /O2 tools\LuaRunner.cpp /Fe:tools\LuaRunner.exe /Fo:tools\LuaRunner.obj
if errorlevel 1 exit /b 1
set "NOTO_SANS_SC_FILE=%~dp0assets\fonts\NotoSansSC-VF.ttf"
if defined NOTO_SANS_SC_FONT set "NOTO_SANS_SC_FILE=%NOTO_SANS_SC_FONT%"
tools\FontAtlas.exe src\Locales\Fonts "Noto Sans SC" "%NOTO_SANS_SC_FILE%"
if errorlevel 1 exit /b 1
if "%~1"=="--all-fonts" (
  tools\FontAtlas.exe src\Locales\Fonts\ja-JP "Noto Sans JP" assets\fonts\NotoSansJP-VF.ttf
  if errorlevel 1 exit /b 1
  tools\FontAtlas.exe src\Locales\Fonts\ko-KR "Noto Sans KR" assets\fonts\NotoSansKR-VF.ttf
  if errorlevel 1 exit /b 1
)
echo Build completed. Run start.cmd to launch PoB2.
