# Set up Node-Exporter

# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Dependencies](#dependencies)
- [Installation](#installation)

## Dependencies
### Make sure to install [Tailscale](https://tailscale.com/download) on all VM (Machine)
Tailscale will make your IP permanently event if you restart the machine.

## Installation
Update the user name **devops** to your own user in the bash script .sh

There are 5 steps to set up Central Prometheus.

1. **Install required libs**

2. **Create dedicated system user `node_exporter`** to run Prometheus securely

3. **Install the standalone Node Exporter** (version 1.10.0 by default — feel free to update to the latest).

4. **Create self-signed cert** username: prometheus, password: 123qwe!@#4

5. **Create a `node_exporter` service using systemd**.
