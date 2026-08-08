@echo off
setlocal enabledelayedexpansion

title TicketDesk — Start All Services

set "JAVA=java"
set "MVN=mvn"
set "ROOT=%~dp0backend"
set "FRONTEND=%~dp0frontend"
set "PATH=%PATH%;C:\Program Files\nodejs"

cls
echo.
echo  ============================================================
echo    TicketDesk Enterprise — Microservices Architecture
echo  ============================================================
echo.

set "SERVICES=eureka-server api-gateway auth-service ticket-service comment-service attachment-service dashboard-service"

echo  [1/2] Checking ^& Building service JARs if needed...
echo.

for %%S in (%SERVICES%) do (
    if not exist "%ROOT%\%%S\target\%%S-1.0.0-SNAPSHOT.jar" (
        echo      Building %%S...
        call "%MVN%" -f "%ROOT%\%%S\pom.xml" clean package -DskipTests -q
        if errorlevel 1 (
            echo      [ERROR] Build failed for %%S
            pause
            exit /b 1
        )
    )
    echo      [OK] %%S ready
)

echo.
echo  [2/2] Starting all independent microservices...
echo.

:: ── Kill any processes on our ports ──────────────────────────────────────────
for %%P in (8761 8080 8089 8082 8084 8085 8087) do (
    for /f "tokens=5" %%i in ('netstat -ano 2^>nul ^| findstr /R "0\.0\.0\.0:%%P "') do (
        taskkill /PID %%i /F >nul 2>&1
    )
)
ping 127.0.0.1 -n 2 >nul

:: ── 1. Eureka Discovery Server (Port 8761) ───────────────────────────────────
echo   1. Eureka Server       → http://localhost:8761
start /MIN "eureka-server :8761" "%JAVA%" -jar "%ROOT%\eureka-server\target\eureka-server-1.0.0-SNAPSHOT.jar"
echo      Waiting for Eureka Server initialization...
ping 127.0.0.1 -n 11 >nul

:: ── 2. API Gateway (Port 8080) ───────────────────────────────────────────────
echo   2. API Gateway         → http://localhost:8080
start /MIN "api-gateway :8080" "%JAVA%" -jar "%ROOT%\api-gateway\target\api-gateway-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 5 >nul

:: ── 3. Microservices ─────────────────────────────────────────────────────────
echo   3. auth-service        → http://localhost:8089 (Registered with Eureka)
start /MIN "auth-service :8089" "%JAVA%" -jar "%ROOT%\auth-service\target\auth-service-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 4 >nul

echo   4. ticket-service      → http://localhost:8082 (Registered with Eureka)
start /MIN "ticket-service :8082" "%JAVA%" -jar "%ROOT%\ticket-service\target\ticket-service-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 4 >nul

echo   5. comment-service     → http://localhost:8084 (Registered with Eureka)
start /MIN "comment-service :8084" "%JAVA%" -jar "%ROOT%\comment-service\target\comment-service-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 4 >nul

echo   6. attachment-service  → http://localhost:8085 (Registered with Eureka)
start /MIN "attachment-service :8085" "%JAVA%" -jar "%ROOT%\attachment-service\target\attachment-service-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 4 >nul

echo   7. dashboard-service   → http://localhost:8087 (Registered with Eureka)
start /MIN "dashboard-service :8087" "%JAVA%" -jar "%ROOT%\dashboard-service\target\dashboard-service-1.0.0-SNAPSHOT.jar"
ping 127.0.0.1 -n 6 >nul

:: ── 8. React Frontend (Port 3000) ────────────────────────────────────────────
echo   8. React Frontend      → http://localhost:3000 (Routing via API Gateway :8080)
start /MIN "frontend :3000" cmd /c "cd /d "%FRONTEND%" && npm run dev"
ping 127.0.0.1 -n 6 >nul

:: ── Open browser ─────────────────────────────────────────────────────────────
echo.
echo   Opening browser...
start "" "http://localhost:3000"

echo.
echo  ============================================================
echo   All 7 Spring Boot services + Frontend running!
echo.
echo   - Eureka Dashboard : http://localhost:8761
echo   - API Gateway      : http://localhost:8080
echo   - React Web App    : http://localhost:3000
echo.
echo   LOGIN CREDENTIALS
echo   -----------------
echo   Admin  : admin@ticketdesk.com  /  admin123
echo.
echo   To stop all services, run stop-all.bat
echo  ============================================================
echo.
pause
