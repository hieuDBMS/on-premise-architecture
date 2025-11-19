# Set up SonarQube

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

1. **Install the required Java version** (OpenJDK 17) and make it available for all users by exporting the environment variables to /etc/profile

2. **Install the standalone SonarQube Community Edition** (version 25.10.0 by default — feel free to update to the latest). Then create a dedicated system user (`sonarqube`) to run the service securely.

3. **Config the database connection and system resource limits** to ensure SonarQube run smoothly and does not crash under load. Finally, create a `sonarqube` versive using systemd.

