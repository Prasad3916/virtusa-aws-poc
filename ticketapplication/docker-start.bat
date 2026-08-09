@echo off
title TicketDesk — Docker Compose Start
echo.
echo  ============================================================
echo    TicketDesk Enterprise — Starting Docker Containers
echo  ============================================================
echo.

cd /d "%~dp0"
docker compose up --build -d

echo.
echo  ============================================================
echo   All services are launching in Docker containers!
echo.
echo   - Frontend Web App : http://localhost:3000
echo   - Eureka Dashboard : http://localhost:8761
echo   - API Gateway      : http://localhost:8080
echo.
echo   Check status with: docker compose ps
echo   View logs with   : docker compose logs -f
echo  ============================================================
echo.
pause
