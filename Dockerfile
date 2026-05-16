# Etapa 1: Compilar la aplicación con Maven
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Etapa 2:asdasd Crear la imagen final y ligera para producción
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# TIP: Usar *.jar evita que tengas que cambiar el Dockerfile si cambia la versión en tu pom.xm l
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]