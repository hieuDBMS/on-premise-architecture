# Set up Central Grafana

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

There are 3 steps to set up SonarQube.

1. **Install required libs and create dedicated system user (`sonarqube`)** to run the service securely

2. **Install the standalone Grafana** (version 12.2.1 by default — feel free to update to the latest).

3. **Create a `grafana` service using systemd**.