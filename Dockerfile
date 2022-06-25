FROM maven:3.8.6-jdk-1
COPY . .
RUN mvn clean install
COPY ./target/*.jar springbootapp.jar
ENTRYPOINT ["java", "-jar", "springbootapp.jar"]