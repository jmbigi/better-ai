@echo off
setlocal
set "ROOT=%~dp0.."
where py >nul 2>nul
if %errorlevel% equ 0 (
    py "%ROOT%\scripts\doc_validator.py" --root "%ROOT%"
    exit /b %errorlevel%
)
where python >nul 2>nul
if %errorlevel% equ 0 (
    python "%ROOT%\scripts\doc_validator.py" --root "%ROOT%"
    exit /b %errorlevel%
)
echo Se requiere Python 3 (comando py o python) 1>&2
exit /b 1
