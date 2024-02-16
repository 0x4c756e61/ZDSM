#!/usr/bin/env bash
ZDSM_HOME="/var/srv/zdsm"
ZDSM_USER="zdsm-user"

info() {
  echo -e "\x1b[38;2;57;62;65m[$(date +"%T")]\x1b[0m \x1b[38;2;86;164;255mINFO\x1b[0m \t-- $*"
}

error() {
  echo -e "\x1b[38;2;57;62;65m[$(date +"%T")]\x1b[0m \x1b[38;2;246;96;96mERROR\x1b[0m \t-- $*"
  exit 1
}

warn() {
  echo -e "\x1b[38;2;57;62;65m[$(date +"%T")]\x1b[0m \x1b[38;2;255;237;129mWARN\x1b[0m \t-- $*"
}


success() {
  echo -e "\x1b[38;2;179;255;114m✓\x1b[0m Sucessfully installed.\n"
}


checkIfRoot() {
  if [ "$EUID" -eq 0 ]; then
    error This script cannot be ran as root ! You\'ll ve prompted for sudo when needed.
  fi
  
}

checkIfCurlInstalled() {
  if ! command -v curl >/dev/null 2>&1; then
    error "Curl wasn't found on this system, please make sure it is installed correctly and retry."
  fi
  
}

installSystemService() {
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "Looks like you are not using systemD, you will have to create your system service by yourself !"
    info "Here's some helpfull informations:"

    info "User: ${ZDSM_USER}"
    info "Home: ${ZDSM_HOME}"
    info "Executable: ${ZDSM_HOME}/zdsm"
    info "Config file: ${ZDSM_HOME}/.env"
    
  else
    info "Creating service file"
    echo "[Unit]
Description=ZDSM unit service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=1
User=${ZDSM_USER}
ExecStart=${ZDSM_HOME}/zdsm
WorkingDirectory=${ZDSM_HOME}

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/zdsm.service
  fi

  
  
}

main() {
  checkIfRoot 
  checkIfCurlInstalled

  info "Adding user ${ZDSM_USER}"
  sudo mkdir -p ${ZDSM_HOME}
  sudo useradd -rUb ${ZDSM_HOME} ${ZDSM_USER}

  info "Downloading ZDSM@latest"
  curl -L https://github.com/0x454d505459/ZDSM/releases/latest/download/zdsm --output /tmp/zdsm
  sudo mv /tmp/zdsm ${ZDSM_HOME}

  sudo chown -R ${ZDSM_USER}:${ZDSM_USER} ${ZDSM_HOME}

  installSystemService
  
  success  
}

main
