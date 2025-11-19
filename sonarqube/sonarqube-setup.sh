#!/bin/bash

# This script install java jdk17
function update_install_java {
    apt update -y
    # Install OpenJDK 17 and common tools
    apt install -y openjdk-17-jdk wget unzip net-tools
    
    # Back up /etc/profile
    cp /etc/profile /etc/profile_backup

    # Set environment variables (for all users)
    grep -qxF "export JAVA_HOME=${JAVA_HOME_PATH}" /etc/profile || echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' | tee -a /etc/profile
    grep -qxF "export JRE_HOME=${JAVA_HOME_PATH}" /etc/profile || echo 'export JRE_HOME=/usr/lib/jvm/java-17-openjdk-amd64' | tee -a /etc/profile
    grep -qxF 'export PATH=$JAVA_HOME/bin:$PATH' /etc/profile || echo 'export PATH=$JAVA_HOME/bin:$PATH' | tee -a /etc/profile

    # Apply the new environment variables
    source /etc/profile

    # verify installation
    java -version
    echo "JAVA_HOME is set to $JAVA_HOME"
}

function install_sonar {
    # Use temp folder
    cd /tmp
    # pull repo sonarqube
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.10.0.114319.zip
    # unzip sonarqube
    unzip -o sonarqube-25.10.0.114319.zip
    # install SonarQube at /opt/sonarqube-25.10.0.11431
    mv sonarqube-25.10.0.114319/ /opt/sonarqube
    # Create a dedicated sonarqube system user without login priviledges and a home directory
    adduser --system --no-create-home --group --disabled-login sonarqube
    # grant the sonarqube user full privileges to /opt/sonarqube-25.10.0.11431
    chown -R sonarqube:sonarqube /opt/sonarqube
}

function config_sonar {
    # The -server flag tells the JVM to use the server VM instead of the client VM.
    cat >> /opt/sonarqube/conf/sonar.properties << EOF
# Database information
sonar.jdbc.username=sonaruser
sonar.jdbc.password=123qwe!@#4
sonar.jdbc.url=jdbc:postgresql://100.111.71.105:5432/sonarqube
sonar.web.javaAdditionalOpts=-server
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

    # Open the sysctl.config configuration file to modify the system memory limits.
    # vm.max_map_count=524288: Increases the number of memory maps Elasticsearch can use, allowing it to handle large datasets.
    # fs.file-max=131072: Increases the maximum number of files Elasticsearch can open, allowing it to run efficiently.
    cat >> /etc/sysctl.conf << EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

    # Create resource limits for SonarQube user
    cat > /etc/security/limits.d/99-sonarqube.conf << EOF
# SonarQube resource limits
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOF

    # Apply the new sysctl settings immediately
    sysctl -p

    # Allow All network connect
    ufw disable
    # Check uwf
    ufw status
    # Make a file to manage Sonar service via systemctl
    cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonarqube
Group=sonarqube
PermissionsStartOnly=true
Restart=always

StandardOutput=syslog
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to apply the service changes
    systemctl daemon-reload

    # Enable SonarQube to start at boot
    systemctl enable sonarqube
    # Start the SonarQube service
    systemctl start sonarqube
    # View the sonarQube service status and verify that it's running
    systemctl status sonarqube
}

function install_auto_sonar {
    update_install_java
    install_sonar
    config_sonar
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
        install_auto_sonar
        echo "[✅ SUCCESS] SonarQube installation completed on Ubuntu!"
    elif [[ $OS == "centos" || $OS == "amzn" || $OS == "amazon" ]]; then
        install_auto_sonar
        echo "[✅ SUCCESS] SonarQube installation completed on CentOS/Amazon Linux!"
    else
        echo "[❌ ERROR] This operating system is not supported."
        exit 1
    fi
}

main