#!/bin/bash

function install_libs {
    apt update -y
    # Install wget
    apt install -y wget apache2-utils
}

function create_user {
    groupadd --system node_exporter
    useradd --system --no-create-home --gid node_exporter --shell /usr/sbin/nologin node_exporter
    echo "Node Exporter user created successfully."
}

function install_node_exporter {
    # Download and extract prometheus
    wget https://github.com/prometheus/node_exporter/releases/download/v1.10.0/node_exporter-1.10.0.linux-amd64.tar.gz
    tar -xvf node_exporter-1.10.0.linux-amd64.tar.gz
    cd node_exporter-1.10.0.linux-amd64
    # Move the node exporter executable to user/local/bin for all users executable
    cp node_exporter /usr/local/bin/
    # Change the owner for the node_exporter executable
    chown node_exporter:node_exporter /usr/local/bin/node_exporter
    # Back to current folder
    cd ..
}

function setup_encrypt_authentication {
    # Encryption: All cert and configs will be store in /etc/node_exporter/
    mkdir -p /etc/node_exporter
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -keyout /etc/node_exporter/node_exporter.key \
        -out /etc/node_exporter/node_exporter.crt \
        -subj "/C=VN/ST=Ho Chi Minh City/L=Ho Chi Minh City/O=FIS/CN=localhost" \
        -addext "subjectAltName = DNS:localhost"

    # Authentication: username is prometheus, password is '123qwe!@#4'
    prometheus_passwd=$(htpasswd -nBC 12 "" | tr -d ':\n')
    # Store the password
    echo "$prometheus_passwd" > /etc/node_exporter/authentication.txt

    # Store password hash to authentication folder
    # Write Encryption and Authentication to config.yaml
    cat > /etc/node_exporter/config.yaml << EOF
tls_server_config:
    cert_file: node_exporter.crt
    key_file: node_exporter.key
basic_auth_users:
    prometheus: $prometheus_passwd
EOF

    # Change the chown for node_exporter to read
    chown -R node_exporter:node_exporter /etc/node_exporter

}

function create_service {
    # Allow All network connect
    ufw disable
    # Check uwf status
    ufw status
    # Create Prometheus Service via systemd
    cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --web.config.file=/etc/node_exporter/config.yaml

[Install]
WantedBy=multi-user.target
EOF
    # Reload the systemd ti apply the service changes
    systemctl daemon-reload
    # Enable and start prometheus service
    systemctl enable node_exporter
    systemctl start node_exporter
    systemctl status node_exporter
    echo "Node Exporter Service created successfully."
}

function install_auto_node_exporter {
    install_libs
    create_user
    install_node_exporter
    setup_encrypt_authentication
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
        install_auto_node_exporter
        echo "[✅ SUCCESS] SonarQube installation completed on Ubuntu!"
    elif [[ $OS == "centos" || $OS == "amzn" || $OS == "amazon" ]]; then
        install_auto_node_exporter
        echo "[✅ SUCCESS] SonarQube installation completed on CentOS/Amazon Linux!"
    else
        echo "[❌ ERROR] This operating system is not supported."
        exit 1
    fi
}

main
