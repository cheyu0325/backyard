#!/bin/bash

set -e

# --- Parse Args ---
if [ -z "$1" ]; then
  echo "❌ 請輸入模組名稱，例如： ./create-spring-core-module.sh util-core [--default-profile=dev]"
  exit 1
fi

MODULE_NAME=$1
DEFAULT_PROFILE=""

# 解析可選參數 --default-profile=xxx
for arg in "$@"; do
  if [[ $arg == --default-profile=* ]]; then
    DEFAULT_PROFILE="${arg#*=}"
  fi
done

# 如果沒指定 profile，預設為 dev
if [[ -z "$DEFAULT_PROFILE" ]]; then
  DEFAULT_PROFILE="dev"
  echo "ℹ️ 未指定 profile，預設使用: dev"
else
  echo "✅ 使用指定的 profile: ${DEFAULT_PROFILE}"
fi

# --- Path Setup ---
GROUP_NAME="com.cheyu.fz2h"
PACKAGE_BASE="${GROUP_NAME}.${MODULE_NAME//-/.}"
MODULE_DIR="./${MODULE_NAME}"
JAVA_DIR="${MODULE_DIR}/src/main/java/$(echo ${PACKAGE_BASE} | tr '.' '/')"
TEST_DIR="${MODULE_DIR}/src/test/java/$(echo ${PACKAGE_BASE} | tr '.' '/')"
RESOURCES_DIR="${MODULE_DIR}/src/main/resources"

CAP_MODULE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${MODULE_NAME:0:1})${MODULE_NAME:1}"
CLASS_NAME="${CAP_MODULE_NAME}Application"

echo "📁 建立模組目錄: ${MODULE_NAME}"
mkdir -p "${JAVA_DIR}"
mkdir -p "${TEST_DIR}"
mkdir -p "${RESOURCES_DIR}"

# --- Gradle build file ---
echo "📝 建立 build.gradle（Spring Core + Test）"
cat > "${MODULE_DIR}/build.gradle" <<EOF
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
    implementation 'org.springframework.boot:spring-boot-starter'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}
EOF

# --- Java Main Class ---
echo "📝 建立主類別: ${CLASS_NAME}.java"
cat > "${JAVA_DIR}/${CLASS_NAME}.java" <<EOF
package ${PACKAGE_BASE};

import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.SpringApplication;

@SpringBootApplication
public class ${CLASS_NAME} {
    public static void main(String[] args) {
        SpringApplication.run(${CLASS_NAME}.class, args);
    }
}
EOF

# --- Unit Test ---
echo "🧪 建立測試: ${CLASS_NAME}Test.java"
cat > "${TEST_DIR}/${CLASS_NAME}Test.java" <<EOF
package ${PACKAGE_BASE};

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class ${CLASS_NAME}Test {

    @Test
    void testContextLoads() {
        assertTrue(true);
    }
}
EOF

# --- YAML config files ---
echo "📄 建立 application.yaml 與 profiles（default: ${DEFAULT_PROFILE}）"
cat > "${RESOURCES_DIR}/application.yaml" <<EOF
spring:
  application:
    name: ${MODULE_NAME}
  profiles:
    active: ${DEFAULT_PROFILE}
EOF

cat > "${RESOURCES_DIR}/application-dev.yaml" <<EOF
app:
  env: dev
logging:
  level:
    root: DEBUG
    org.springframework: DEBUG
spring:
  jmx:
    enabled: false
EOF

cat > "${RESOURCES_DIR}/application-test.yaml" <<EOF
app:
  env: test
logging:
  level:
    root: DEBUG
    org.springframework: DEBUG
spring:
  jmx:
    enabled: false
EOF

cat > "${RESOURCES_DIR}/application-prod.yaml" <<EOF
app:
  env: prod
logging:
  level:
    root: WARN
    org.springframework: WARN
spring:
  jmx:
    enabled: false
EOF

# --- Add to settings.gradle ---
echo "🔧 更新 settings.gradle..."
SETTINGS_FILE="settings.gradle"
if ! grep -q "include '${MODULE_NAME}'" "${SETTINGS_FILE}" 2>/dev/null; then
    echo "🔧 加入 '${MODULE_NAME}' 到 settings.gradle"
    echo "include '${MODULE_NAME}'" >> "${SETTINGS_FILE}"
else
    echo "✅ settings.gradle 已包含 '${MODULE_NAME}'"
fi

# --- Append build ignore ---
echo "📄 更新 .gitignore..."
GITIGNORE_FILE=".gitignore"
BUILD_IGNORE_LINE="${MODULE_NAME}/build/"
if [ -f "$GITIGNORE_FILE" ]; then
  if ! grep -q "^${BUILD_IGNORE_LINE}$" "$GITIGNORE_FILE"; then
    echo "🔒 加入 .gitignore: ${BUILD_IGNORE_LINE}"
    echo -e "\n# Ignore build artifacts from ${MODULE_NAME}\n${BUILD_IGNORE_LINE}" >> "$GITIGNORE_FILE"
  else
    echo "✅ .gitignore 已包含 ${BUILD_IGNORE_LINE}"
  fi
else
  echo "# Ignore build artifacts from ${MODULE_NAME}\n${BUILD_IGNORE_LINE}" > "$GITIGNORE_FILE"
fi

echo "✅ Spring Core 模組 ${MODULE_NAME} 建立完成！預設 Profile 為 ${DEFAULT_PROFILE}。"
