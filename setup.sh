#!/usr/bin/env bash
# Beacon — Setup Script
# Guides you through setting up your Beacon streaming server.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}  Beacon — Live Streaming Setup${RESET}"
echo "  ================================"
echo ""

# 1. Check Docker
echo -e "${BOLD}[1/8] Checking Docker...${RESET}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed.${RESET}"
    echo "  Install it from: https://docs.docker.com/engine/install/"
    exit 1
fi
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose is not available.${RESET}"
    echo "  Install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}  Docker and Docker Compose found.${RESET}"

# 2. Check .env
echo ""
echo -e "${BOLD}[2/8] Checking configuration...${RESET}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}  Created .env from .env.example${RESET}"
    echo ""
    read -rp "  Enter your domain (e.g. stream.yourgroup.org): " DOMAIN
    sed -i.bak "s/DOMAIN=.*/DOMAIN=${DOMAIN}/" .env && rm -f .env.bak
    read -rp "  Enter your email (for SSL certificate): " EMAIL
    sed -i.bak "s/EMAIL=.*/EMAIL=${EMAIL}/" .env && rm -f .env.bak
    read -rp "  Enter an admin password for the /status page: " ADMIN_PASSWORD
    sed -i.bak "s/ADMIN_PASSWORD=.*/ADMIN_PASSWORD=${ADMIN_PASSWORD}/" .env && rm -f .env.bak
    read -rp "  YouTube stream key (leave blank to skip): " YOUTUBE_STREAM_KEY
    if [ -n "${YOUTUBE_STREAM_KEY}" ]; then
        sed -i.bak "s/YOUTUBE_STREAM_KEY=.*/YOUTUBE_STREAM_KEY=${YOUTUBE_STREAM_KEY}/" .env && rm -f .env.bak
    fi
else
    echo -e "${GREEN}  .env file found.${RESET}"
fi

source .env

echo "  Domain: ${DOMAIN}"

# 3. Generate .htpasswd
echo ""
echo -e "${BOLD}[3/8] Generating auth file...${RESET}"
if command -v htpasswd &> /dev/null; then
    htpasswd -nb admin "${ADMIN_PASSWORD}" > nginx/.htpasswd
else
    docker run --rm httpd:alpine htpasswd -nb admin "${ADMIN_PASSWORD}" > nginx/.htpasswd
fi
echo -e "${GREEN}  nginx/.htpasswd created.${RESET}"

# 4. Configure YouTube relay if key provided
echo ""
echo -e "${BOLD}[4/8] Configuring stream settings...${RESET}"
if [ -n "${YOUTUBE_STREAM_KEY:-}" ]; then
    echo -e "${GREEN}  YouTube relay enabled — toggle it from the streamer UI when live.${RESET}"
else
    echo "  Self-hosted only (no YouTube relay). Add YOUTUBE_STREAM_KEY to .env to enable."
fi

# 5. Check DNS and resolve public IP for WebRTC
echo ""
echo -e "${BOLD}[5/8] Checking DNS...${RESET}"
PUBLIC_IP=""
if command -v dig &> /dev/null; then
    RESOLVED=$(dig +short "${DOMAIN}" 2>/dev/null | head -1)
    if [ -z "${RESOLVED}" ]; then
        echo -e "${YELLOW}  Warning: ${DOMAIN} does not resolve yet.${RESET}"
        echo "  Make sure your DNS A record points to this server's IP before continuing."
        read -rp "  Continue anyway? (y/n): " CONTINUE
        [ "${CONTINUE}" != "y" ] && exit 0
    else
        echo -e "${GREEN}  ${DOMAIN} resolves to ${RESOLVED}${RESET}"
        PUBLIC_IP="${RESOLVED}"
    fi
else
    echo -e "${YELLOW}  'dig' not found — skipping DNS check.${RESET}"
fi

# Try to detect public IP if DNS didn't give us one
if [ -z "${PUBLIC_IP}" ]; then
    PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
    if [ -n "${PUBLIC_IP}" ]; then
        echo "  Detected public IP: ${PUBLIC_IP}"
    fi
fi

# 6. Configure WebRTC NAT traversal
echo ""
echo -e "${BOLD}[6/8] Configuring WebRTC...${RESET}"
if [ -n "${PUBLIC_IP}" ]; then
    sed -i.bak "s|webrtcICEHostNAT1To1IPs:.*|webrtcICEHostNAT1To1IPs: [${PUBLIC_IP}]|" mediamtx/mediamtx.yml && rm -f mediamtx/mediamtx.yml.bak
    echo -e "${GREEN}  WebRTC NAT configured with IP: ${PUBLIC_IP}${RESET}"
else
    echo -e "${YELLOW}  Could not detect public IP. WebRTC may not work from external networks.${RESET}"
    echo "  To fix: edit mediamtx/mediamtx.yml and set webrtcICEHostNAT1To1IPs to your server's public IP."
fi

# 7. Get SSL certificate and start services
echo ""
echo -e "${BOLD}[7/8] Getting SSL certificate and starting services...${RESET}"

mkdir -p certbot-certs certbot-webroot

CERTBOT_EMAIL_FLAG="--register-unsafely-without-email"
if [ -n "${EMAIL:-}" ] && [ "${EMAIL}" != "you@example.com" ]; then
    CERTBOT_EMAIL_FLAG="--email ${EMAIL} --no-eff-email"
fi

docker run --rm \
    -p 80:80 \
    -v "$(pwd)/certbot-certs:/etc/letsencrypt" \
    -v "$(pwd)/certbot-webroot:/var/www/certbot" \
    certbot/certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    ${CERTBOT_EMAIL_FLAG} \
    -d "${DOMAIN}"

echo -e "${GREEN}  SSL certificate obtained.${RESET}"

# Start all services
echo ""
docker compose up -d

# 8. Health check
echo ""
echo -e "${BOLD}[8/8] Health check...${RESET}"
sleep 5
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" 2>/dev/null || echo "000")
if [ "${HTTP_CODE}" = "200" ]; then
    echo -e "${GREEN}  Beacon is running!${RESET}"
else
    echo -e "${YELLOW}  Got HTTP ${HTTP_CODE} — the server may still be starting up.${RESET}"
    echo "  Try: curl -k https://${DOMAIN}/"
fi

echo ""
echo "  ================================"
echo -e "${BOLD}  Beacon is ready.${RESET}"
echo ""
echo "  Landing page:     https://${DOMAIN}/"
echo "  Streamer (you):   https://${DOMAIN}/go.html"
echo "  Viewer (anyone):  https://${DOMAIN}/watch.html"
echo "  Status (admin):   https://${DOMAIN}/status"
echo ""
echo "  To go live: open the streamer URL on your phone and tap GO LIVE."
echo "  To share: send the viewer URL or scan the QR code that appears."
echo ""
