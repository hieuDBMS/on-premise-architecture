# Set up Central Prometheus

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

## Installation
Update the user name **devops** to your own user in the bash script .sh

There are 7 steps to set up Central Prometheus.

1. **Install required libs**

2. Create dedicated system user `prometheus` to run Prometheus securely

3. **Install the standalone Prometheus** (version 3.5.0 by default — feel free to update to the latest).

4. **Create self-signed cert**

5. **Create folder for storing self-signed certs of node-exporter**

6. **Configure your prometheus.yaml** to scrape metrics from exporter/federate

7. **Create a `prometheus` service using systemd**.

## Node Exporter
- If you use Node-Exporter for exporting the metrics, make sure to copy the self-signed ca cert to Prometheus at `/etc/<folder-name-of-each-node-exporter>`for Authentication and Encryption.

## Federate
- Central Prometheus collects metrics from other Prometheus using federate. If you set up prometheus in cluster via rancher, you can use my ingress.yaml with tls or non-tls. After apply this ingress.yaml, the central Prometheus can scrape data from it.
