# Set up Fluent-Bit
![alt text](Elasticsearch-cluster.svg)
# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Node Exporter](#node-exporter)
- [Federate](#federate)

## Dependencies
### Make sure to install [Tailscale](https://tailscale.com/download) on all VM (Machine)
Tailscale will make your IP permanently event if you restart the machine.

### Ingress controller is installed on cluster

## Installation
1. Install Fluent-bit Repo using Helm
    ```
    helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update
    helm search repo fluent
    ```

2. Create values file to custom your config
    ```
    sudo vi fluent-bit-values.yaml -> create values file
    ```

    **Fluent Bit Values Overview**
    1. Lua Script:
        - Remove ANSI color codes from application logs.
        - Extracts structured fields (timestamp, service, traceId, spanId, userId, level, logger, method...)
        - Adds parsed fields back into the log record
        - Ensures clean, searchable logs in Elasticsearch
    2. Inputs 
        - Tail Input
            - Reads logs from /var/log/containers/*.log
            - Excludes noisy logs (Prometheus, Ingress, Calico, Rancher)
            - Tags logs as kube.*

        - Systemd Input
            - Helps monitor the health of the Kubernetes nodes via systemd logs
            - Captures host-level logs from kubelet.service
            - Tagged as host.home.*
    3. Filters
        - Kubernetes Filter
            - Enriches logs with Kubernetes metadata (pod, namespace, labels)
            - Keeps raw log (Keep_Log On).
            - Disables container’s own log parser to avoid double parsing.
        
        - Lua Filter
            - Runs the custom Lua script
            - Cleans logs and extracts structured fields
    
    4. Outputs
        - Two Elasticsearch outputs
            - Container logs (index k8s-logs-home)
            - Host logs (index k8s-logs-home)
        
        - Both include:
            - TLS enabled
            - Retry logic
            - Buffered sending
            - Credentials and remote host configurations

3. Install Fluent-bit in fluent-bit name space
    ```
    helm upgrade --install fluent-bit fluent/fluent-bit   --namespace fluent-bit --create-namespace   -f fluent-bit-values.yaml
    ```