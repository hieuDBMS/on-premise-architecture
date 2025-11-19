# Set up Cluster

# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Usage](#usage)

## Dependencies
### Make sure to install [Tailscale](https://tailscale.com/download) on all VM (Machine)
Tailscale will make your IP permanently event if you restart the machine.

## Installation
Update the user name **devops** to your own user in the bash script .sh

Make sure to init your cluster with IP of tailscale apiserver-advertise-address=<TAILSCALE_IP>

I will use Calico as Container Network Interface(CNI) with the POD CIDR 10.244.0.0/16

The version of Kubernetes Cluster will is v1.31

### Set up Master Node (k8s-master.sh)
There are 9 steps to set up cluster

1. Install required system dependencies. These packages enable the system to download files securely, manage external API repository, and verify package signatures. Make sure to permanently disable swap (set up ufw if you want)

    These tools are required for:
    - curl: downloading Kubernetes keys and packages
    - gnupg2: verifying GPG signatures
    - software-properties-common: adding external APT repositories
    - apt-transport-https: allowing APT to use HTTPS sources
    - ca-certificates: ensuring trusted SSL certificates for secure downloads

2. Configure kernel modules and system networking
Kubernetes networking requires certain Linux kernel modules and sysctl parameters to be enabled. These settings ensure that the container networking layer, especially using CNIs like Calico, Flannel, or Cilium can correctly route and manage traffic.

    The script loads and persists the following kernel modules:
    - overlay: Enable the OverlayFS filesystem, required by container runtime.
    - br_netfilter: Allow linux bridges to process iptables rules, which is essential for Kubernetes network traffic routing.

    Next, sysctl parameters are configured:
    ```
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    ```
    These settings accomplish the following:
    - Enable iptables processing for bridged IPv4/6 traffic -> Kubernetes network packets flowing through CNI bridges are visible to iptables rules.
    - Enable IP forwarding on the node so pods and services can route traffic.

    Finally, `sysctl --system` applies these settings immediately and ensures they persist after reboot.

3. Install containerd for our master

4. Install Kubernetes v1.31 (kubelet kubeadm kubectl)

5. Kubernetes uses several core container images when initializing the cluster with kubeadm init (API server, controller manager, scheduler, etcd, CoreDNS, and pause images).
    ```
    kubeadm config images pull
    ```
Running that forces the node to download all required Kubernetes images before the cluster installation begins. The upcoming kubeadm init or kubeadm join will run faster.

6. Initialize your cluster

7. For user(s) to use the kubectl, you must to have:
    - The cluster API server address
    - Certificates for authentication
    - Credentials for the admin user

    Each user needs their own copy of config file /etc/kubernetes/admin.conf under ~/.kube/config
    This step 7 will copy admin.conf for **root** and **devops** users.

8. Install Calico CNI with custom values (calico-custom.yaml) with POD_CIDR="10.244.0.0/16"

9. Install all helm and repos for helm (Just need to install this on master node)

### Set up Workers Node (k8s-worker.sh)
1. Install required system dependencies. These packages enable the system to download files securely, manage external API repository, and verify package signatures. Make sure to permanently disable swap (set up ufw if you want)

    These tools are required for:
    - curl: downloading Kubernetes keys and packages
    - gnupg2: verifying GPG signatures
    - software-properties-common: adding external APT repositories
    - apt-transport-https: allowing APT to use HTTPS sources
    - ca-certificates: ensuring trusted SSL certificates for secure downloads

2. Configure kernel modules and system networking
Kubernetes networking requires certain Linux kernel modules and sysctl parameters to be enabled. These settings ensure that the container networking layer, especially using CNIs like Calico, Flannel, or Cilium can correctly route and manage traffic.

    The script loads and persists the following kernel modules:
    - overlay: Enable the OverlayFS filesystem, required by container runtime.
    - br_netfilter: Allow linux bridges to process iptables rules, which is essential for Kubernetes network traffic routing.

    Next, sysctl parameters are configured:
    ```
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    ```
    These settings accomplish the following:
    - Enable iptables processing for bridged IPv4/6 traffic -> Kubernetes network packets flowing through CNI bridges are visible to iptables rules.
    - Enable IP forwarding on the node so pods and services can route traffic.

    Finally, `sysctl --system` applies these settings immediately and ensures they persist after reboot.

3. Install containerd for our master

4. Install Kubernetes v1.31 (kubelet kubeadm kubectl)

5. Kubernetes uses several core container images when initializing the cluster with kubeadm init (API server, controller manager, scheduler, etcd, CoreDNS, and pause images).
    ```
    kubeadm config images pull
    ```
Running that forces the node to download all required Kubernetes images before the cluster installation begins. The upcoming kubeadm init or kubeadm join will run faster.

### Set up Join Worker to Master (join-cluster.sh)
- Change these parameters:
    1. MASTER_STATIC_IP = <YOUR_MASTER_NODE_IP> (Tailscale IP)
    2. JOIN_TOKEN = <YOUR_JOIN_TOKEN> (Generated from kubeadm init, expired after 24h by default)
    3. CERT_HASH = <YOUR_CERT_HASH> (Generated from kubeadm init, no expired)

- Enter the node Role to Identify what the Node will be (worker,..)

- Copy .kube/config of master node to other nodes for using kubectl.