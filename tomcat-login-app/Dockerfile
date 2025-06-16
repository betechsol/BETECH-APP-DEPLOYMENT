# Use a Maven image to build the app
FROM maven:3.8.8-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Use a JRE image to run the app
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/tomcat-login-app-1.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]