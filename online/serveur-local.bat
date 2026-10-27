@echo off
rem Local room server for testing multiplayer games (double-click it).
rem Installs the dependencies the first time, then runs the server on
rem http://127.0.0.1:8787 with the group key "test" (Plugins/Online settings).
cd /d "%~dp0server"
if not exist node_modules (
  echo Installation des dependances...
  call npm ci || goto :error
)
call npm run dev
goto :eof
:error
echo Echec de l'installation : Node.js 22 est-il installe ?
pause
