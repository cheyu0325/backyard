#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "❌ 請輸入模組名稱，例如： ./create-spring-module.sh service-a"
  exit 1
fi

MODULE_NAME=$1
PACKAGE_BASE="com.fz2h.${MODULE_NAME//-/.}"
MODULE_DIR="./$MODULE_NAME"
JAVA_DIR="$MODULE_DIR/src/main/java/$(echo $PACKAGE_BASE | tr '.' '/')"
TEST_DIR="$MODULE_DIR/src/test/java/$(echo $PACKAGE_BASE | tr '.' '/')"

# 將模組名轉為 Application 類別名稱（首字大寫 + Application 結尾）
CAP_MODULE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${MODULE_NAME:0:1})${MODULE_NAME:1}"
APP_CLASS_NAME="${CAP_MODULE_NAME}Application"

echo "📁 建立模組目錄: $MODULE_DIR"
mkdir -p "$JAVA_DIR"
mkdir -p "$TEST_DIR"

echo "📝 建立 build.gradle"
cat > "$MODULE_DIR/build.gradle" <<EOF
plugins {
    id 'org.springframework.boot' version '3.2.5'
    id 'io.spring.dependency-management' version '1.1.4'
    id 'java'
}

group = 'com.fz2h'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}
EOF

echo "📝 建立 Application 主類別: $APP_CLASS_NAME.java"
cat > "$JAVA_DIR/$APP_CLASS_NAME.java" <<EOF
package $PACKAGE_BASE;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class $APP_CLASS_NAME {
    public static void main(String[] args) {
        SpringApplication.run($APP_CLASS_NAME.class, args);
    }
}
EOF

# 自動加入 settings.gradle（groovy）
SETTINGS_FILE="settings.gradle"
if ! grep -q "include '$MODULE_NAME'" "$SETTINGS_FILE"; then
    echo "🔧 加入 '$MODULE_NAME' 到 settings.gradle"
    echo "include '$MODULE_NAME'" >> "$SETTINGS_FILE"
else
    echo "✅ settings.gradle 已包含 '$MODULE_NAME'"
fi

echo "✅ 子模組 $MODULE_NAME 建立完成！"
