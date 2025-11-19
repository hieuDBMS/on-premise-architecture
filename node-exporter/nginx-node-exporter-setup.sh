#!/bin/bash

function install_libs {
    apt update -y
    # Install wget
    apt install -y wget apache2-utils
}

function create_user {
    groupadd --system nginx_exporter
    useradd --system --no-create-home --gid nginx_exporter --shell /usr/sbin/nologin nginx_exporter
    
    echo "NGINX Exporter user created successfully."
}

function install_nginx_exporter {
    # Download and extract nginx_exporter
    wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v1.5.1/nginx-prometheus-exporter_1.5.1_linux_amd64.tar.gz
    tar -xvf nginx-prometheus-exporter_1.5.1_linux_amd64.tar.gz
    # Move the nginx exporter executable to /usr/local/bin
    cp nginx-prometheus-exporter /usr/local/bin/
    # Change the owner for the nginx_exporter executable
    chown nginx_exporter:nginx_exporter /usr/local/bin/nginx-prometheus-exporter
    rm -rf nginx-prometheus-exporter*
    echo "NGINX Exporter installed successfully."
}

function setup_encrypt_authentication {
    # Encryption: All cert and configs will be store in /etc/nginx_exporter/
    mkdir -p /etc/nginx_exporter
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -keyout /etc/nginx_exporter/nginx_exporter.key \
        -out /etc/nginx_exporter/nginx_exporter.crt \
        -subj "/C=VN/ST=Ho Chi Minh City/L=Ho Chi Minh City/O=FIS/CN=localhost" \
        -addext "subjectAltName = DNS:localhost"

    # Authentication: username is prometheus, password is '123qwe!@#4'
    prometheus_passwd=$(htpasswd -nBC 12 "" | tr -d ':\n')
    # Store the password
    echo "$prometheus_passwd" > /etc/nginx_exporter/authentication.txt

    # Store password hash to authentication folder
    # Write Encryption and Authentication to config.yaml
    cat > /etc/nginx_exporter/config.yaml << EOF
tls_server_config:
    cert_file: nginx_exporter.crt
    key_file: nginx_exporter.key
basic_auth_users:
    prometheus: $prometheus_passwd
EOF

    # Change the chown for node_exporter to read
    chown -R nginx_exporter:nginx_exporter /etc/nginx_exporter

}

function create_nginx_exporter_service {
    # Allow All network connections
    ufw disable
    # Check ufw status
    ufw status
    
    # Create NGINX Exporter Service via systemd
    cat > /etc/systemd/system/nginx_exporter.service << EOF
[Unit]
Description=NGINX Prometheus Exporter
Wants=network-online.target
After=network-online.target nginx.service

[Service]
User=nginx_exporter
Group=nginx_exporter
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
    -nginx.scrape-uri=http://127.0.0.1:9999/stub_status \
    -web.config.file=/etc/nginx_exporter/config.yaml

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload the systemd to apply the service changes
    systemctl daemon-reload
    # Enable and start nginx_exporter service
    systemctl enable nginx_exporter
    systemctl start nginx_exporter
    systemctl status nginx_exporter
    echo "NGINX Exporter Service created successfully on port 9113."
}

function install_auto_nginx_exporter {
    install_libs
    create_user
    install_nginx_exporter
    setup_encrypt_authentication
    create_nginx_exporter_service
}

function show_summary {
    echo ""
    echo "========================================"
    echo "✅ Installation Complete!"
    echo "========================================"
    echo ""
    echo "📊 NGINX Exporter Running:"
    echo "  • Endpoint: http://localhost:9113/metrics"
    echo "  • NGINX stub_status: http://localhost:9999/stub_status"
    echo ""
    echo "📝 Add to Prometheus config (prometheus.yml):"
    echo ""
    echo "scrape_configs:"
    echo "  - job_name: 'nginx'"
    echo "    static_configs:"
    echo "      - targets: ['<this-server-ip>:9113']"
    echo ""
    echo "🧪 Test endpoint:"
    echo "  curl http://localhost:9113/metrics"
    echo "  curl http://localhost:9999/stub_status"
    echo ""
    echo "🔍 Available metrics include:"
    echo "  • nginx_connections_active"
    echo "  • nginx_connections_accepted"
    echo "  • nginx_connections_handled"
    echo "  • nginx_http_requests_total"
    echo ""
    echo "⚠️  Note: stub_status provides basic metrics."
    echo "   For latency/response time, consider NGINX access log parsing."
    echo ""
    echo "========================================"
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
        install_auto_nginx_exporter
        show_summary
        echo "[✅ SUCCESS] NGINX Exporter installation completed on Ubuntu!"
    elif [[ $OS == "centos" || $OS == "amzn" || $OS == "amazon" ]]; then
        install_auto_nginx_exporter
        show_summary
        echo "[✅ SUCCESS] NGINX Exporter installation completed on CentOS/Amazon Linux!"
    else
        echo "[❌ ERROR] This operating system is not supported."
        exit 1
    fi
}

main