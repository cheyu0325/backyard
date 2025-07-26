#!/bin/bash

set -e

# ------------- Platform Detection -------------
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu)
        echo "ubuntu"
        ;;
      debian)
        echo "debian"
        ;;
      rhel | centos | rocky | almalinux)
        echo "redhat"
        ;;
      *)
        echo "unknown"
        ;;
    esac
  else
    echo "unknown"
  fi
}

# ------------- SDKMAN Installation per OS -------------

install_sdkman_macos() {
  echo "✅ Detected macOS"
  echo "📦 Installing SDKMAN..."
  curl -s "https://get.sdkman.io" | bash
  echo "✅ SDKMAN installed. Run: source \$HOME/.sdkman/bin/sdkman-init.sh"
}

install_sdkman_ubuntu_debian() {
  echo "✅ Detected Ubuntu/Debian"
  echo "📦 Installing curl and zip if missing..."
  sudo apt update
  sudo apt install -y curl zip unzip
  echo "📦 Installing SDKMAN..."
  curl -s "https://get.sdkman.io" | bash
  echo "✅ SDKMAN installed. Run: source \$HOME/.sdkman/bin/sdkman-init.sh"
}

install_sdkman_redhat() {
  echo "✅ Detected RedHat/CentOS/Rocky"
  echo "📦 Installing curl and zip if missing..."
  sudo yum install -y curl zip unzip
  echo "📦 Installing SDKMAN..."
  curl -s "https://get.sdkman.io" | bash
  echo "✅ SDKMAN installed. Run: source \$HOME/.sdkman/bin/sdkman-init.sh"
}

install_sdkman_unknown() {
  echo "❌ Unsupported or unknown OS."
  exit 1
}

# ------------- Main Logic -------------
main() {
  OS_TYPE=$(detect_os)
  case "$OS_TYPE" in
    macos)
      install_sdkman_macos
      ;;
    ubuntu | debian)
      install_sdkman_ubuntu_debian
      ;;
    redhat)
      install_sdkman_redhat
      ;;
    *)
      install_sdkman_unknown
      ;;
  esac
}

main
