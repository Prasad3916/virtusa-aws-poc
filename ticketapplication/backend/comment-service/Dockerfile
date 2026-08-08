FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN apk add --no-cache maven && mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh \
 && addgroup -S appgroup \
 && adduser -S appuser -G appgroup \
 && chown -R appuser:appgroup /app
USER appuser
EXPOSE 8084
ENTRYPOINT ["/app/docker-entrypoint.sh"]