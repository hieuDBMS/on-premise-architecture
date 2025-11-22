# Set up Cluster Elasticsearch
![alt text](Elasticsearch-cluster.svg)
# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Handle Issues](#handle-issues)

## Dependencies
### Make sure to install [Tailscale](https://tailscale.com/download) on all VM (Machine)
Tailscale will make your IP permanently event if you restart the machine.

### Make sure to install helm on master node
Elasticsearch cluster is install using helm chart

### Ingress controller is installed on cluster

### Other must use the tls .key and .crt files in elasticsearch-master-certs created by Master Node to connect to each other.
Make sure to enable options in data and ingest nodes:
```
xpack.security.http.ssl.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
```

## Installation

There are 6 steps to set up Cluster Elasticsearch.

1. **Create storageclass and persistent volume in elastic namespace** by running:
```
kubectl apply status storageclass.yaml -n elastic
```

2. **Label Each Your Worker Node to have these lables**. For example:
```
kubectl label node k8s-worker-1 elastic-data=true
kubectl label node k8s-worker-2 elastic-data=true
kubectl label node k8s-worker-3 elastic-data=true
kubectl label node k8s-worker-1 elastic-master=true
kubectl label node k8s-worker-2 elastic-ingest=true
```

3. **Install the Master Node First** by running:
```
helm install elasticsearch-master elastic/elasticsearch -f master-values.yaml -n elastic 
```

4. **Install the Data Node** by running:
```
helm install elasticsearch-data elastic/elasticsearch -f data-values.yaml -n elastic
```
- The Data Node connect to the Master Node using:
    1. masterService: "<cluster-name>-<node-group>" (Example: "elasticsearch-master")
    2. secretMountsL: Get the secret of master node from namespace elastic
    3. nodeSelector: Select the worker node with elastic-data=true
    4. volumeClaimTemplate: Store data in Persistent Volume at local path `/data/elasticsearch/es-data-pv`

5. **Install the Ingest Node** by running:
```
helm install elasticsearch-ingest elastic/elasticsearch -f ingest-values.yaml -n elastic
```
6. **Create ingress.yaml to expose the elasticsearch outside the cluster**. The data nodes are used to store, indexes data, handle search and CURD -> I expose these data nodes outside the cluster.

    **Notes**: If you install kibana outside the cluster, you should create host for elasticsearch-master in ingress.yaml.

## Handle Issues
### When master-node is re-created
All Data Nodes store the old Cluster UUID, when Master Node is re-created -> Have to join new UUID.
**You should create PVC for master, ingest, and data nodes to make sure UUID, data are consistent**