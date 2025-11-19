#!/bin/bash

# Kubernetes Worker Node Setup Script for Calico CNI
# For Ubuntu LTS with Kubernetes v1.31

set -e

echo "=================================================="
echo "Kubernetes Worker Node Setup for Calico CNI"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: sudo $0"

step "Step 1: System preparation..."
# Update system
apt update
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Permanently disable swap
log "Permanently disabling swap..."
swapoff -a
# Remove all swap entries from fstab
sed -i '/swap/d' /etc/fstab
# Disable swap in systemd
systemctl mask swap.target
log "Swap permanently disabled"

# Disable firewall
ufw disable

# Configure devops user if exists
if id devops &>/dev/null; then
    log "Configuring devops user..."
    usermod -aG sudo devops
    echo "devops ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devops
    chmod 777 /etc/sudoers.d/devops
    mkdir -p /home/devops/.kube
    chmod 777 /home/devops/.kube
    chown -R devops:devops /home/devops/.kube
fi

step "Step 2: Configure kernel modules..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay 
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
log "Kernel modules configured"

step "Step 3: Install containerd..."
# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt update -y
apt install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup and fix sandbox image
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sed -i 's|registry.k8s.io/pause:3.8|registry.k8s.io/pause:3.10|g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
log "containerd configured"

step "Step 4: Install Kubernetes..."
# Add Kubernetes repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
log "Kubernetes installed"

step "Step 5: Pre-pull images..."
kubeadm config images pull
log "Images pre-pulled"

# Clean up any previous installation
if [[ -f /etc/kubernetes/kubelet.conf ]]; then
    warn "Cleaning previous installation..."
    kubeadm reset -f
fi

echo ""
echo "=================================================="
echo -e "${GREEN}✅ Worker Node Setup Complete!${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Join the cluster using the command from master:"
echo "   sudo kubeadm join <MASTER-IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>"
echo ""
echo "2. Copy kubectl config from master (optional for worker):"
echo "   scp devops@master:/home/devops/.kube/config /home/devops/.kube/config"
echo "   chown devops:devops /home/devops/.kube/config"
echo ""
echo "3. Verify from master: kubectl get nodes"
echo ""
echo -e "${GREEN}✅ Ready for Calico CNI${NC}"
echo -e "${GREEN}✅ Swap permanently disabled${NC}"