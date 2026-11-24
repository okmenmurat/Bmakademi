@echo off
title BE Mentor Akademi - Yerel Sunucu
start "" "http://localhost:8090/index.html"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0baslat.ps1" -Port 8090
