@echo off
node "%~dp0tools\check-localisation-display.cjs"
if errorlevel 1 exit /b 1
cd /d "%~dp0src"
if not exist Tests\Run mkdir Tests\Run
type nul > Tests\Run\.ready
..\tools\LuaRunner.exe Tests\Localisation.lua
if errorlevel 1 exit /b 1
..\tools\LuaRunner.exe Tests\LocalisationIntegration.lua
exit /b %errorlevel%
