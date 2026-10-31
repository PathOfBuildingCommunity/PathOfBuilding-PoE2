@echo off
python "%~dp0tools\run-localisation-tests.py" %*
exit /b %errorlevel%
