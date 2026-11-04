@echo off
rem GODOT4 env var first, then the usual desktop install
if defined GODOT4 (
  start "" "%GODOT4%" --path "%~dp0game"
  exit /b
)
start "" "%USERPROFILE%\OneDrive\орн▒\godot\Godot_v4.6.2-stable_win64.exe" --path "%~dp0game"
