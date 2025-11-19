# Set up Nginx LoadBalancer

# Getting started

To make it easy for you to get started with this project, here's a list of recommended next steps.

# Contents
- [Installation](#installation)

## Installation
1. Install NGINX - FULL (This will provide you with full module)
```
apt install nginx-full
```

2. Create <your-name>.conf file in `conf.d`. For example
```
upstream cluster-1-http {
    server k8s-worker-1:30080;
    server k8s-worker-2:30080;
    server k8s-worker-3:30080;
}

upstream cluster-1-https {
    server k8s-worker-1:30443;
    server k8s-worker-2:30443;
    server k8s-worker-3:30443;
}

upstream cluster-2-http {
    server k8s-worker-1e:30080;
    server k8s-worker-2e:30080;
    server k8s-worker-4e:30080;
}

upstream cluster-2-https {
    server k8s-worker-1e:30443;
    server k8s-worker-2e:30443;
    server k8s-worker-4e:30080;
}

upstream prometheus-https {
    server k8s-worker-1:30443;
    server k8s-worker-2:30443;
    server k8s-worker-3:30443;
    server k8s-worker-1e:30443;
    server k8s-worker-2e:30443;
    server k8s-worker-4e:30080;
}

server {
    # Listen on the standard HTTP port
    listen 80;
    server_name interpay.bbtech.io.vn interpay-dev.bbtech.io.vn interpay-sit.bbtech.io.vn interpay-uat.bbtech.io.vn interpay-dev.hieuminh.io.vn ebank.bbtech.io.vn bo-portal-dev.bbtech.io.vn prometheus-cluster.bbtech.io.vn;
    location / {
        proxy_pass http://cluster-2-http;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl http2;
    server_name interpay.bbtech.io.vn interpay-dev.bbtech.io.vn interpay-sit.bbtech.io.vn interpay-uat.bbtech.io.vn interpay-dev.hieuminh.io.vn ebank.bbtech.io.vn bo-portal-dev.bbtech.io.vn;
    ssl_certificate certs/bbtech_io_vn/tls.crt;
    ssl_certificate_key certs/bbtech_io_vn/tls.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    location / {
        proxy_pass http://cluster-2-http;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

}

server {
    listen 443 ssl http2;
    server_name prometheus-cluster-home.bbtech.io.vn;
    ssl_certificate certs/bbtech_io_vn/tls.crt;
    ssl_certificate_key certs/bbtech_io_vn/tls.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    location / {
        proxy_pass https://cluster-2-https;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

}

server {
    listen 443 ssl http2;
    server_name prometheus-cluster-fis.bbtech.io.vn kibana.bbtech.io.vn es.bbtech.io.vn;
    ssl_certificate certs/bbtech_io_vn/tls.crt;
    ssl_certificate_key certs/bbtech_io_vn/tls.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    client_max_body_size 100M;
    location / {
        proxy_pass https://cluster-1-https;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

}
```

3. Check your Nginx is valid
```
sudo nginx -t
```

4. Reload nginx to apply new changes
```
sudo systemctl reload nginx
```
