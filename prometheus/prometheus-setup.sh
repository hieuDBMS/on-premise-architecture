#!/bin/bash

TARGET=("registry" "loadbalancer" "jenkins" "sonarqube" "databases" "cluster")

function install_libs {
    apt update -y
    # Install wget
    apt install -y wget apache2-utils
}

function create_user {
    groupadd --system prometheus
    useradd --system --no-create-home --gid prometheus --shell /usr/sbin/nologin prometheus
    echo "Prometheus user created successfully."
}

function install_prometheus {
    # Create folder for storing configuration files
    mkdir /etc/prometheus
    # Create folder for storing our data
    mkdir /var/lib/prometheus
    # Change the owner for both folders
    chown prometheus:prometheus /etc/prometheus
    chown prometheus:prometheus /var/lib/prometheus
    # Download and extract prometheus
    wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
    tar -xvf prometheus-3.5.0.linux-amd64.tar.gz
    cd prometheus-3.5.0.linux-amd64
    # Move the prometheus executable to user/local/bin for all users executable
    cp prometheus /usr/local/bin/
    cp promtool /usr/local/bin/
    # Change the owner for both binaries
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool
    # Move the configuration files to /etc/prometheus
    cp -r consoles/ /etc/prometheus/
    cp -r console_libraries/ /etc/prometheus/
    cp prometheus.yml /etc/prometheus/
    # Change the owner for configuration files
    chown -R prometheus:prometheus /etc/prometheus/consoles
    chown -R prometheus:prometheus /etc/prometheus/console_libraries
    chown -R prometheus:prometheus /etc/prometheus/prometheus.yml
    # Back to current folder
    cd ..
    echo "Prometheus installed successfully."
}

function setup_encrypt_authentication {
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -keyout /etc/prometheus/prometheus.key \
        -out /etc/prometheus/prometheus.crt \
        -subj "/C=VN/ST=Ho Chi Minh City/L=Ho Chi Minh City/O=FIS/CN=localhost" \
        -addext "subjectAltName = DNS:localhost"
    # Authentication: username is prometheus, password is '123qwe!@#4'
    prometheus_passwd=$(htpasswd -nBC 12 "" | tr -d ':\n')
    # Store the password
    echo "$prometheus_passwd" > /etc/prometheus/authentication.txt
    # Write Encryption and Authentication to config.yaml
    cat > /etc/prometheus/config.yaml << EOF
tls_server_config:
    cert_file: prometheus.crt
    key_file: prometheus.key
basic_auth_users:
    prometheus: $prometheus_passwd
EOF
    chown -R prometheus:prometheus /etc/prometheus

}

function create_folder_self_signed_cert {
    for t in "${TARGET[@]}"; do
        # Create directory if it doesn't exist
        mkdir -p "/etc/${t}"
    done
}

function create_service {
    # Allow All network connect
    ufw disable
    # Check uwf status
    ufw status
    # Create Prometheus Service via systemd
    cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --storage.tsdb.retention.time=30d \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
    # --web.config.file=/etc/prometheus/config.yaml

[Install]
WantedBy=multi-user.target
EOF
    # Reload the systemd to apply the service changes
    systemctl daemon-reload
    # Enable and start prometheus service
    systemctl enable prometheus
    systemctl start prometheus
    systemctl status prometheus
    echo "Prometheus Service created successfully."
}

function install_auto_prometheus {
    install_libs
    create_user
    install_prometheus
    setup_encrypt_authentication
    create_folder_self_signed_cert
    create_service
}

function main {
    # Detect OS name cleanly
    OS=$(grep -Poi '^id=.*' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')

    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        echo "❌ This script must be run as root." >&2
        exit 1
    fi

    echo "🔍 Detected OS: $OS"

    # OS-specific logic
    if [[ $OS == "ubuntu" ]]; then
        install_auto_prometheus
        echo "[✅ SUCCESS] SonarQube installation completed on Ubuntu!"
    elif [[ $OS == "centos" || $OS == "amzn" || $OS == "amazon" ]]; then
        install_auto_prometheus
        echo "[✅ SUCCESS] SonarQube installation completed on CentOS/Amazon Linux!"
    else
        echo "[❌ ERROR] This operating system is not supported."
        exit 1
    fi
}

main