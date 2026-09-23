@echo off
start "nvgraph" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0nvgraph.ps1"
