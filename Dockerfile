FROM maven:3.8.6-jdk-1

COPY . /myapp
WORKDIR /myapp

RUN mvn clean install -DskipTests

ENTRYPOINT ["java", "-jar", "/myapp/targetspringbootapp.jar"]