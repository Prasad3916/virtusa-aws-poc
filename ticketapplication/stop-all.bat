@echo off
title TicketDesk — Stop All Services

echo.
echo  Stopping all TicketDesk microservices...
echo.

for %%P in (8761 8080 8089 8082 8084 8085 8087 3000) do (
    for /f "tokens=5" %%i in ('netstat -ano 2^>nul ^| findstr /R "0\.0\.0\.0:%%P "') do (
        echo   Killing port %%P (PID %%i)...
        taskkill /PID %%i /F >nul 2>&1
    )
)

echo.
echo  All 7 services + frontend stopped successfully.
echo.
pause
