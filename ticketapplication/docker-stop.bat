@echo off
title TicketDesk — Docker Compose Stop
echo.
echo Stopping all TicketDesk Docker containers...
cd /d "%~dp0"
docker compose down
echo.
echo All containers stopped successfully.
pause
