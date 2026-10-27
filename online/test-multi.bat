@echo off
rem Local test of a multiplayer game (double-click it): opens the room server,
rem the host's bridge (Tom) that creates the room, and a second player's
rem bridge (Leo) that joins it. Then start a New Game in the game, and type
rem "go" in Tom's window. Rules of the test room: change them below.
set RULES=--nuzlocke required --same-type
cd /d "%~dp0"
set CODE_FILE=%TEMP%\typelocked-salon.txt
if exist "%CODE_FILE%" del "%CODE_FILE%"

start "Serveur local" cmd /k call serveur-local.bat
echo Attente du serveur local...
:wait_server
timeout /t 2 /nobreak >nul
curl.exe -s -o nul http://127.0.0.1:8787/ || goto wait_server

start "Tom (hote)" cmd /k node bridge\src\cli.js create --name Tom %RULES% --code-file "%CODE_FILE%"
:wait_code
timeout /t 1 /nobreak >nul
if not exist "%CODE_FILE%" goto wait_code
set /p CODE=<"%CODE_FILE%"

rem The second player has its own identity folder and local port.
start "Leo (joueur 2)" cmd /k "set APPDATA=%~dp0joueur2&& set TYPELOCKED_PORT=47121&& node bridge\src\cli.js join %CODE% --name Leo"
echo Salon %CODE% : lance une Nouvelle partie dans le jeu, puis tape go dans la fenetre de Tom.
pause
