#!/usr/bin/env bash
# Beacon — Initial SSL certificate acquisition
# Run this standalone if you need to get/renew certs outside of setup.sh.

set -euo pipefail

if [ ! -f .env ]; then
    echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
    exit 1
fi

source .env

if [ -z "${DOMAIN:-}" ]; then
    echo "Error: DOMAIN is not set in .env"
    exit 1
fi

echo "Requesting SSL certificate for ${DOMAIN}..."
echo "Make sure port 80 is open and DNS points to this server."
echo ""

CERTBOT_EMAIL_FLAG="--register-unsafely-without-email"
if [ -n "${EMAIL:-}" ] && [ "${EMAIL}" != "you@example.com" ]; then
    CERTBOT_EMAIL_FLAG="--email ${EMAIL} --no-eff-email"
fi

mkdir -p certbot-certs certbot-webroot

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

echo ""
echo "SSL certificate obtained for ${DOMAIN}"
echo "You can now run: docker compose up -d"
