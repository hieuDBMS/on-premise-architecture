#!/bin/bash
set -e

# -------------------------------
# Variables
# -------------------------------
HARBOR_DOMAIN="registry.bbtech.io.vn"
NAMESPACE="harbor"
HARBOR_PASSWORD="123qwe!@#4"
HARBOR_VERSION="1.18.0"
DEVOPS_USER="devops"
NODE_IP="100.64.241.90"

# -------------------------------
# Configure sudo access for devops user
# -------------------------------
echo "[INFO] Configuring sudo access for $DEVOPS_USER user..."

# Add devops user to sudo group
sudo usermod -aG sudo $DEVOPS_USER

# Configure passwordless sudo
echo "$DEVOPS_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$DEVOPS_USER > /dev/null
sudo chmod 440 /etc/sudoers.d/$DEVOPS_USER

echo "[INFO] Passwordless sudo configured for $DEVOPS_USER"


# -------------------------------
# Install K3s with custom config
# -------------------------------
echo "[INFO] Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - \
    --node-ip="$NODE_IP" \
    --bind-address="$NODE_IP" \
    --write-kubeconfig-mode 644

echo "[INFO] Waiting for K3s..."
until kubectl get nodes &>/dev/null; do sleep 2; done
sleep 10

# -------------------------------
# Configure kubectl access for devops user
# -------------------------------
echo "[INFO] Configuring kubectl access for $DEVOPS_USER user..."

# Create .kube directory for devops user
sudo mkdir -p /home/$DEVOPS_USER/.kube

# This configures kubectl for the CURRENT user running the script
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml /home/$DEVOPS_USER/.kube/config

# Change ownership to devops user
sudo chown -R $DEVOPS_USER:$DEVOPS_USER /home/$DEVOPS_USER/.kube

# Set proper permissions
sudo chmod 600 /home/$DEVOPS_USER/.kube/config

echo "[INFO] kubectl configured for $DEVOPS_USER user"

# Install Helm
if ! command -v helm &> /dev/null; then
  echo "[INFO] Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# -------------------------------
# Create namespace
# -------------------------------
echo "[INFO] Creating namespace..."
kubectl create ns $NAMESPACE 2>/dev/null || true

# -------------------------------
# Configure K3s registry for HTTP (insecure)
# -------------------------------
echo "[INFO] Configuring K3s registry for HTTP access..."
sudo mkdir -p /etc/rancher/k3s/

cat <<EOF | sudo tee /etc/rancher/k3s/registries.yaml
mirrors:
  "$HARBOR_DOMAIN":
    endpoint:
      - "https://$HARBOR_DOMAIN"
configs:
  "$HARBOR_DOMAIN":
    tls:
      insecure_skip_verify: true
EOF

echo "[INFO] Restarting K3s to apply registry configuration..."
sudo systemctl restart k3s

echo "[INFO] Waiting for K3s to be fully ready..."
sleep 10

# Wait for API server to be responsive
until kubectl get nodes &>/dev/null; do 
    echo "Waiting for K3s API server..."
    sleep 3
done

echo "[INFO] K3s is ready"
sleep 5

# -------------------------------
# Add Harbor Helm repo
# -------------------------------
echo "[INFO] Adding Harbor helm repo..."
helm repo add harbor https://helm.goharbor.io
helm repo update

# -------------------------------
# Create Harbor values for HTTP
# -------------------------------
cat > harbor-values.yaml <<EOF
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-ingress
  ingress:
    hosts:
      core: rgistry.bbtech.io.vne
    className: traefik
    annotations:
      # 1. Increase the timeout for the entire upload process
      traefik.ingress.kubernetes.io/requestbody.timeout: "3600s" 
      
      # 2. Disable request buffering to prevent timeouts during large streams
      #    This directly addresses the possible Buffering Middleware issue.
      traefik.ingress.kubernetes.io/buffering.requestbody: "false" 

externalURL: https://registry.bbtech.io.vn

harborAdminPassword: $HARBOR_PASSWORD

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      storageClass: "local-path"
      size: 70Gi
    jobservice:
      storageClass: "local-path"
      size: 2Gi
    database:
      storageClass: "local-path"
      size: 10Gi
    redis:
      storageClass: "local-path"
      size: 1Gi
    trivy:
      storageClass: "local-path"
      size: 3Gi

# Resource limits for 8GB RAM
trivy:
  enabled: true
  resources:
    requests:
      memory: 128Mi
      cpu: 50m
    limits:
      memory: 256Mi
      cpu: 200m

core:
  resources:
    requests:
      memory: 512Mi
      cpu: 300m
    limits:
      memory: 768Mi
      cpu: 800m

registry:
  resources:
    requests:
      memory: 512Mi
      cpu: 300m
    limits:
      memory: 768Mi
      cpu: 800m

jobservice:
  resources:
    requests:
      memory: 128Mi
      cpu: 50m
    limits:
      memory: 256Mi
      cpu: 200m

database:
  internal:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 400m

redis:
  internal:
    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi
        cpu: 200m

portal:
  resources:
    requests:
      memory: 64Mi
      cpu: 50m
    limits:
      memory: 128Mi
      cpu: 100m
EOF

# -------------------------------
# Install Harbor
# -------------------------------
echo "[INFO] Installing Harbor (this may take 5-10 minutes)..."
helm install harbor harbor/harbor \
    --version $HARBOR_VERSION \
    -n $NAMESPACE \
    -f harbor-values.yaml \
    --wait \
    --timeout 10m

# -------------------------------
# Update /etc/hosts
# -------------------------------
echo "[INFO] Updating /etc/hosts..."
if ! grep -q "$HARBOR_DOMAIN" /etc/hosts; then
    echo "127.0.0.1 $HARBOR_DOMAIN" | sudo tee -a /etc/hosts
    echo "$NODE_IP $HARBOR_DOMAIN" | sudo tee -a /etc/hosts
fi


# -------------------------------
# Done
# -------------------------------
echo ""
echo "========================================="
echo "[SUCCESS] Harbor is installed (HTTP)!"
echo "========================================="
echo "Access: https://$HARBOR_DOMAIN"
echo "Username: admin"
echo "Password: $HARBOR_PASSWORD"
echo ""
echo "⚠️  WARNING: Using HTTP (insecure) configuration"
echo "   This is NOT recommended for production use!"
echo ""
echo "User '$DEVOPS_USER' configured with:"
echo "  ✓ Passwordless sudo access"
echo "  ✓ kubectl access (no sudo needed)"
echo ""
echo "Docker configured with insecure registry:"
echo "  ✓ $HARBOR_DOMAIN"
echo "  ✓ $NODE_IP"
echo ""
echo "To verify access (as $DEVOPS_USER):"
echo "  kubectl get nodes"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To test Harbor:"
echo "  docker login $HARBOR_DOMAIN"
echo "  docker tag myimage:latest $HARBOR_DOMAIN/library/myimage:latest"
echo "  docker push $HARBOR_DOMAIN/library/myimage:latest"
echo ""
echo "NOTE: Logout and login again for all group changes to take effect"
echo "========================================="