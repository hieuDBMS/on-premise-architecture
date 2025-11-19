# Set up Ingress Controller

# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Dependencies](#dependencies)
- [Installation](#installation)

## Dependencies
Make sure to set up cluster first!

## Installation
1. Add repo to Helm
```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm list repo
```

2. Pull the helm chart `ingress-nginx/ingress-nginx`
```
helm pull ingress-nginx/ingress-nginx
```

3. Extract the ingress-controller
```
tar -xzf ingress-nginx-<your_version>.tgz 
```

4. Change the type of Ingress-Controller from LoadBalancer(default) to NodePort
```
sudo vi values.yaml
# Modify service type to NodePort
Set nodePorts http: "30080" and https: "30443" 
```

5. Create namespace and install
```
kubectl create ns ingress-nginx
helm -n ingress-nginx install ingress-nginx -f ingress-nginx/values.yaml ingress-nginx
helm list -n ingress-nginx
kubectl get all -n ingress-nginx
```

6. After install successfully, Ingress Controller will expose all of your nodes to users
