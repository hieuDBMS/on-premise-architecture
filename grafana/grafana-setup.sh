#!/bin/bash

function install_libs {
    apt update -y
    # Install wget
    apt install -y wget
}

function create_user {
    groupadd --system grafana
    useradd --system --no-create-home --gid grafana --shell /usr/sbin/nologin grafana
    echo "Grafana user created successfully"
}

function install_grafana {
    # Download and extract grafana
    wget https://dl.grafana.com/grafana/release/12.2.1/grafana_12.2.1_18655849634_linux_amd64.tar.gz
    tar -zxvf grafana_12.2.1_18655849634_linux_amd64.tar.gz
    # Move and change the name of extracted folder
    mv grafana-12.2.1 /usr/local/grafana
    # Change the owner for binaries
    chown -R grafana:grafana /usr/local/grafana
    echo "Grafana installed successfully"
}

function create_service {
    # Allow All network connect
    uwf disable
    # Check uwf status
    ufw status
    # Create Grafana Service via systemd
    cat > /etc/systemd/system/grafana.service << EOF
[Unit]
Description=Grafana Server
After=network.target

[Service]
Type=simple
User=grafana
Group=grafana
ExecStart=/usr/local/grafana/bin/grafana server \
    --config=/usr/local/grafana/conf/defaults.ini \
    --homepath=/usr/local/grafana
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    # Reload the systemd to apply the service changes
    systemctl daemon-reload
    # Enable and start grafana service
    systemctl enable grafana
    systemctl start grafana
    systemctl status grafana
    echo "Grafana Service created successfully"
}

function install_auto_grafana {
    install_libs
    create_user
    install_grafana
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
        install_auto_grafana
        echo "[✅ SUCCESS] Grafana installation completed on Ubuntu!"
    elif [[ $OS == "centos" || $OS == "amzn" || $OS == "amazon" ]]; then
        install_auto_grafana
        echo "[✅ SUCCESS] Grafana installation completed on CentOS/Amazon Linux!"
    else
        echo "[❌ ERROR] This operating system is not supported."
        exit 1
    fi
}

main