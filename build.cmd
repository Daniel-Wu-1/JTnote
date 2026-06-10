@echo off
call "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
cd /d "%~dp0"
echo === Building JTnote release ===
call npm run tauri build
