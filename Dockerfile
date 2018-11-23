# First: generate java runtime module by jlink.
FROM openjdk:11-slim as jlink-package

RUN jlink \
     --module-path /opt/java/jmods \
     --compress=2 \
     --add-modules jdk.jfr,jdk.management.agent,java.base,java.logging,java.xml,jdk.unsupported,java.sql,java.naming,java.desktop,java.management,java.security.jgss,java.instrument \
     --no-header-files \
     --no-man-pages \
     --output /opt/jdk-11-mini-runtime

RUN apt-get update && \
    apt-get install -y binutils && \
    strip -p --strip-unneeded /opt/jdk-11-mini-runtime/lib/server/libjvm.so

# Second: generate run image: alpine-openjdk-11-mini
FROM debian:sid-slim

ENV JAVA_HOME=/opt/jdk-11-mini-runtime \
    PATH="$PATH:$JAVA_HOME/bin"

LABEL io.k8s.description="Platform for service spring-boot java applications" \
      io.k8s.display-name="OpenJDK 11" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="runtime,java,java11,openjdk,openjdk11,springboot"

# Copy the jdk-11-mini-runtime from the builder image
COPY --from=jlink-package /opt/jdk-11-mini-runtime /opt/jdk-11-mini-runtime

# Define the application home
RUN useradd -u 1001 -r -g 0 -d /opt/spring-boot -s /sbin/nologin -c "Default Application User" default && \
    mkdir -p /opt/spring-boot && \
    chown -R 1001:0 /opt/spring-boot

# Set the default user for the image, the user itself was created in the base image
USER 1001

# Set the default port for applications built using this image
EXPOSE 8080


# The application's jar file
ARG JAR_FILE=target/hello-gateway-0.0.1-SNAPSHOT.jar

# Add the application's jar to the container
ADD ${JAR_FILE} hello-gateway-0.0.1-SNAPSHOT.jar

# Run the jar file
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/hello-gateway-0.0.1-SNAPSHOT.jar"]

