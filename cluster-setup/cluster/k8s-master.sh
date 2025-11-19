#!/bin/bash

# Kubernetes Master Node Setup Script with Calico CNI
# For Ubuntu LTS with Kubernetes v1.31

set -e

echo "=================================================="
echo "Kubernetes Master Node Setup with Calico CNI"
echo "=================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
[[ $EUID -ne 0 ]] && { log_error "Run as root: sudo $0"; exit 1; }

# Configure devops user if exists
if id devops &>/dev/null; then
    log_info "Configuring devops user..."
    usermod -aG sudo devops
    echo "devops ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devops
    chmod 777 /etc/sudoers.d/devops
fi

log_step "Step 1: System preparation..."
# Update system
apt update
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Permanently disable swap
log_info "Permanently disabling swap..."
swapoff -a
# Comment out all swap entries in fstab
sed -i '/swap/d' /etc/fstab
# Also disable swap in systemd
systemctl mask swap.target
log_info "Swap permanently disabled"

# Disable firewall for simplified setup
ufw disable

log_step "Step 2: Configure kernel modules..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
log_info "Kernel modules configured"

log_step "Step 3: Install containerd..."
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
log_info "containerd installed and configured"

log_step "Step 4: Install Kubernetes..."
# Add Kubernetes repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
log_info "Kubernetes installed"

log_step "Step 5: Pre-pull images..."
kubeadm config images pull
log_info "Images pre-pulled"

log_step "Step 6: Initialize cluster..."
# Configuration variables
MASTER_IP="100.84.218.81"
POD_CIDR="10.244.0.0/16"
K8S_VERSION="v1.31.13"

# Display configuration
log_info "Cluster Configuration:"
log_info "  Master IP: $MASTER_IP"
log_info "  Pod CIDR: $POD_CIDR"
log_info "  Kubernetes Version: $K8S_VERSION"

# Initialize cluster with CORRECT parameters
kubeadm init \
    --apiserver-advertise-address="$MASTER_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --kubernetes-version="$K8S_VERSION"

log_step "Step 7: Configure kubectl..."
# Configure for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Configure for devops user if exists
if id devops &>/dev/null; then
    DEVOPS_HOME="/home/devops"
    mkdir -p "$DEVOPS_HOME/.kube"
    cp -i /etc/kubernetes/admin.conf "$DEVOPS_HOME/.kube/config"
    chown -R devops:devops "$DEVOPS_HOME/.kube"
    log_info "kubectl configured for devops user"
fi

log_step "Step 8: Install Calico CNI..."
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml

# Create Calico configuration with custom CIDR
cat > calico-custom.yaml << EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: $POD_CIDR
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

sleep 10

kubectl apply -f calico-custom.yaml

log_info "Waiting for Calico to be ready..."
sleep 30

log_step "Step 9: Install helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
# Adding repos for helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

log_step "Step 10: Verify cluster status..."
kubectl get nodes
kubectl get pods --all-namespaces

echo ""
echo "=================================================="
echo -e "${GREEN}MASTER NODE SETUP COMPLETED!${NC}"
echo "=================================================="
echo ""
echo -e "${GREEN}✅ Calico CNI installed${NC}"
echo -e "${GREEN}✅ Swap permanently disabled${NC}"
echo -e "${GREEN}✅ Pod CIDR: $POD_CIDR${NC}"
echo ""

# Generate join command
KUBEADM_JOIN=$(kubeadm token create --print-join-command)
echo -e "${YELLOW}Worker Node Join Command:${NC}"
echo "sudo $KUBEADM_JOIN"
echo ""

# Also save join command to file
echo "$KUBEADM_JOIN" > /root/join-command.txt
echo -e "${YELLOW}Join command saved to: /root/join-command.txt${NC}"
echo -e "${YELLOW}Cluster info saved to: /root/cluster-info.txt${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run the worker setup script on each worker node"
echo "2. Use the join command above on each worker node"
echo "3. Verify: kubectl get nodes"
echo "4. Check cluster info: kubectl cluster-info"