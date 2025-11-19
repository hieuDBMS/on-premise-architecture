#!/bin/bash

# Kubernetes Worker Join Script with Calico CNI Support
# Simplified version with role labeling

set -e

echo "=================================================="
echo "Joining Kubernetes Cluster (Calico CNI)"
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

# Master node configuration - UPDATE THESE VALUES
MASTER_STATIC_IP="100.84.218.81"  # Change to your master hostname/IP
JOIN_TOKEN="cj82ar.rleklj1fv0pw0wwu"  # Update with your token
CERT_HASH="sha256:254bfdc4744ddf0aaea92a9000f29e50a3d4ecb6c0f86a449b43c82b730b6381"  # Update with your hash

# Get node role
echo ""
echo -e "${YELLOW}Node Role Configuration:${NC}"
echo "Common roles: worker, compute, storage, gpu, edge"
read -p "Enter role for this node (default: worker): " NODE_ROLE
NODE_ROLE=${NODE_ROLE:-worker}

CURRENT_HOSTNAME=$(hostname)
log "Node: $CURRENT_HOSTNAME, Role: $NODE_ROLE"

echo ""
step "Joining cluster at $MASTER_STATIC_IP..."

# Join the cluster
kubeadm join "$MASTER_STATIC_IP:6443" \
  --token "$JOIN_TOKEN" \
  --discovery-token-ca-cert-hash "$CERT_HASH"

if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo -e "${GREEN}✅ Successfully joined the cluster!${NC}"
    echo "=================================================="
    
    step "Setting up kubectl access..."
    
    # Setup kubectl for devops user
    if id devops &>/dev/null; then
        mkdir -p /home/devops/.kube
        
        # Try to copy config from master
        if scp devops@$MASTER_STATIC_IP:/home/devops/.kube/config /home/devops/.kube/config 2>/dev/null; then
            chown devops:devops /home/devops/.kube/config
            chmod 777 /home/devops/.kube/config
            log "kubectl config copied successfully!"
            
            # Wait for node to be ready
            sleep 15
            
            # Add role label
            step "Adding role label..."
            if su - devops -c "kubectl label node $CURRENT_HOSTNAME node-role.kubernetes.io/$NODE_ROLE=$NODE_ROLE --overwrite" 2>/dev/null; then
                log "Role '$NODE_ROLE' added successfully!"
            else
                warn "Failed to add role label automatically"
            fi
            
            # Show cluster status
            echo ""
            step "Cluster status:"
            su - devops -c "kubectl get nodes" 2>/dev/null || log "kubectl not ready yet"
            
        else
            warn "Could not copy kubectl config automatically"
            echo ""
            echo -e "${YELLOW}Manual setup commands:${NC}"
            echo "scp devops@$MASTER_STATIC_IP:/home/devops/.kube/config /home/devops/.kube/config"
            echo "chown devops:devops /home/devops/.kube/config"
            echo "kubectl label node $CURRENT_HOSTNAME node-role.kubernetes.io/$NODE_ROLE=$NODE_ROLE"
        fi
    else
        warn "User 'devops' not found - skipping kubectl setup"
    fi
    
    echo ""
    echo "=================================================="
    echo -e "${GREEN}✅ Worker Node Joined Successfully!${NC}"
    echo "=================================================="
    echo ""
    echo -e "${YELLOW}Node Details:${NC}"
    echo "- Hostname: $CURRENT_HOSTNAME"
    echo "- Role: $NODE_ROLE" 
    echo "- Master: $MASTER_STATIC_IP"
    echo "- CNI: Calico"
    echo ""
    echo -e "${YELLOW}Verification (run on master):${NC}"
    echo "kubectl get nodes"
    echo "kubectl get nodes --show-labels"
    echo "kubectl get pods --all-namespaces"
    echo ""
    echo -e "${YELLOW}Check Calico pods:${NC}"
    echo "kubectl get pods -n calico-system"
    
else
    error "Failed to join cluster!"
fi