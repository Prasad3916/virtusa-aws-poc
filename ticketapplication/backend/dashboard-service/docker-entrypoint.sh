#!/bin/sh
TASK_IP=$(hostname -i 2>/dev/null | awk '{print $1}')
echo "[entrypoint] Eureka IP: $TASK_IP"
exec java "-Deureka.instance.ip-address=$TASK_IP" -jar /app/app.jar