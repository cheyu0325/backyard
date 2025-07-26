#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "❌ 請輸入模組名稱，例如： ./create-spring-boot-module.sh web-app [--default-profile=dev]"
  exit 1
fi

MODULE_NAME=$1
DEFAULT_PROFILE=""

for arg in "$@"; do
  if [[ $arg == --default-profile=* ]]; then
    DEFAULT_PROFILE="${arg#*=}"
  fi
done

if [[ -z "$DEFAULT_PROFILE" ]]; then
  DEFAULT_PROFILE="dev"
  echo "ℹ️ 未指定 profile，預設使用: dev"
else
  echo "✅ 使用指定的 profile: ${DEFAULT_PROFILE}"
fi

GROUP_NAME="com.cheyu.fz2h"
PACKAGE_BASE="${GROUP_NAME}.${MODULE_NAME//-/.}"
MODULE_DIR="./${MODULE_NAME}"
JAVA_DIR="${MODULE_DIR}/src/main/java/$(echo ${PACKAGE_BASE} | tr '.' '/')"
TEST_DIR="${MODULE_DIR}/src/test/java/$(echo ${PACKAGE_BASE} | tr '.' '/')"
RESOURCES_DIR="${MODULE_DIR}/src/main/resources"

CAP_MODULE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${MODULE_NAME:0:1})${MODULE_NAME:1}"
CLASS_NAME="${CAP_MODULE_NAME}Application"

echo "📁 建立模組目錄: ${MODULE_NAME}"
mkdir -p "$JAVA_DIR/controller" "$JAVA_DIR/service" "$JAVA_DIR/model" "$JAVA_DIR/repository" "$TEST_DIR" "$RESOURCES_DIR"

# --- Gradle build file ---
echo "📝 建立 build.gradle"
cat > "$MODULE_DIR/build.gradle" <<EOF
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.12'
}

apply plugin: 'io.spring.dependency-management'

group = '${GROUP_NAME}'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.projectlombok:lombok:1.18.30'
    annotationProcessor 'org.projectlombok:lombok:1.18.30'
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.1.0'
    runtimeOnly 'org.postgresql:postgresql:42.7.1'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.mockito:mockito-core:5.11.0'
    testImplementation 'org.junit.jupiter:junit-jupiter-api:5.10.2'
    testRuntimeOnly 'org.junit.jupiter:junit-jupiter-engine:5.10.2'
}
EOF

# --- Java Main Class ---
echo "📝 建立主類別: ${CLASS_NAME}.java 與 Sample Classes"
cat > "$JAVA_DIR/${CLASS_NAME}.java" <<EOF
package ${PACKAGE_BASE};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${CLASS_NAME} {
    public static void main(String[] args) {
        SpringApplication.run(${CLASS_NAME}.class, args);
    }
}
EOF

cat > "$JAVA_DIR/controller/SampleController.java" <<EOF
package ${PACKAGE_BASE}.controller;

import ${PACKAGE_BASE}.model.Sample;
import ${PACKAGE_BASE}.service.SampleService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/sample")
public class SampleController {

    @Autowired
    private SampleService sampleService;

    @GetMapping
    public List<Sample> getAll() {
        return sampleService.findAll();
    }

    @PostMapping
    public Sample create(@RequestBody Sample sample) {
        return sampleService.save(sample);
    }

    @PutMapping("/{id}")
    public Sample update(@PathVariable Long id, @RequestBody Sample sample) {
        sample.setId(id);
        return sampleService.save(sample);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        sampleService.delete(id);
    }
}
EOF

cat > "$JAVA_DIR/service/SampleService.java" <<EOF
package ${PACKAGE_BASE}.service;

import ${PACKAGE_BASE}.model.Sample;
import ${PACKAGE_BASE}.repository.SampleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class SampleService {

    @Autowired
    private SampleRepository repository;

    public List<Sample> findAll() {
        return repository.findAll();
    }

    @Transactional
    public Sample save(Sample sample) {
        return repository.save(sample);
    }

    @Transactional
    public void delete(Long id) {
        repository.deleteById(id);
    }
}
EOF

cat > "$JAVA_DIR/model/Sample.java" <<EOF
package ${PACKAGE_BASE}.model;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Data
public class Sample {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String description;
}
EOF

cat > "$JAVA_DIR/repository/SampleRepository.java" <<EOF
package ${PACKAGE_BASE}.repository;

import ${PACKAGE_BASE}.model.Sample;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SampleRepository extends JpaRepository<Sample, Long> {
    Sample findByDescription(String description);
}
EOF

# --- Unit Test ---
echo "🧪 建立測試: ${CLASS_NAME}Test.java"
cat > "$TEST_DIR/SampleServiceTest.java" <<EOF
package ${PACKAGE_BASE};

import ${PACKAGE_BASE}.model.Sample;
import ${PACKAGE_BASE}.repository.SampleRepository;
import ${PACKAGE_BASE}.service.SampleService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
public class SampleServiceTest {

    @Autowired
    SampleService sampleService;

    @Autowired
    SampleRepository sampleRepository;

    @Test
    void testCreateAndFind() {
        Sample s = new Sample();
        s.setDescription("test");
        Sample saved = sampleService.save(s);
        assertNotNull(saved.getId());
        assertEquals("test", saved.getDescription());
    }
}
EOF

# --- YAML config files ---
echo "📄 建立 application.yaml 與 profiles（default: ${DEFAULT_PROFILE}）"
cat > "$RESOURCES_DIR/application.yaml" <<EOF
spring:
  application:
    name: ${MODULE_NAME}
  profiles:
    active: ${DEFAULT_PROFILE}
EOF

cat > "$RESOURCES_DIR/application-${DEFAULT_PROFILE}.yaml" <<EOF
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/${MODULE_NAME}
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 10
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

logging:
  level:
    root: INFO
    org.springframework: INFO
EOF

cat > "$RESOURCES_DIR/application-test.yaml" <<EOF
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/${MODULE_NAME}_test
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 5
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true

logging:
  level:
    root: INFO
    org.springframework: WARN
EOF

cat > "$RESOURCES_DIR/application-prod.yaml" <<EOF
spring:
  datasource:
    url: jdbc:postgresql://prod-db-host:5432/${MODULE_NAME}
    username: prod_user
    password: prod_password
    driver-class-name: org.postgresql.Driver
    hikari:
      maximum-pool-size: 20
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

logging:
  level:
    root: WARN
    org.springframework: ERROR
EOF

echo "🐳 建立 Dockerfile..."
cat > "$MODULE_DIR/Dockerfile" <<EOF
FROM amazoncorretto:17-alpine

WORKDIR /app
COPY build/libs/${MODULE_NAME}-*.jar app.jar

WORKDIR /app/config
COPY build/resources/main/ /app/config/

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

echo "🧱 建立 docker-compose.yml..."
cat > "$MODULE_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  ${MODULE_NAME}:
    build: .
    ports:
      - "8080:8080"
    depends_on:
      - ${MODULE_NAME}-db
    environment:
      SPRING_PROFILES_ACTIVE: ${DEFAULT_PROFILE}
      SPRING_DATASOURCE_URL: jdbc:postgresql://${MODULE_NAME}-db:5432/${MODULE_NAME}
      SPRING_DATASOURCE_USERNAME: postgres
      SPRING_DATASOURCE_PASSWORD: postgres

  ${MODULE_NAME}-db:
    image: postgres:15
    environment:
      POSTGRES_DB: ${MODULE_NAME}
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - ${MODULE_NAME}-data:/var/lib/postgresql/data
    restart: always
    # set shared memory limit when using docker compose
    shm_size: 128mb

volumes:
  ${MODULE_NAME}-data:
EOF

# --- Add to settings.gradle ---
echo "🔧 更新 settings.gradle..."
SETTINGS_FILE="settings.gradle"
if ! grep -q "include '${MODULE_NAME}'" "$SETTINGS_FILE" 2>/dev/null; then
    echo "include '${MODULE_NAME}'" >> "$SETTINGS_FILE"
fi

# --- Append build ignore ---
echo "📄 更新 .gitignore..."
GITIGNORE_FILE=".gitignore"
BUILD_IGNORE_LINE="${MODULE_NAME}/build/"
if [ -f "$GITIGNORE_FILE" ]; then
  if ! grep -q "^${BUILD_IGNORE_LINE}$" "$GITIGNORE_FILE"; then
    echo -e "\n# Ignore build artifacts from ${MODULE_NAME}\n${BUILD_IGNORE_LINE}" >> "$GITIGNORE_FILE"
  fi
else
  echo -e "# Ignore build artifacts from ${MODULE_NAME}\n${BUILD_IGNORE_LINE}" > "$GITIGNORE_FILE"
fi

echo "✅ Spring Boot Web 模組 ${MODULE_NAME} 建立完成，支援 REST API + Service Layer + JPA + PostgreSQL + Swagger + Test + Transaction + Connection Pool！"
