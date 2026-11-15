@echo off
if not exist "%~dp0src\Locales\Fonts\Glyphs.lua" (
  call "%~dp0build.cmd"
  if errorlevel 1 exit /b 1
)
cd /d "%~dp0runtime"
start "" "Path{space}of{space}Building-PoE2.exe"
