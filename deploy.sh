#!/bin/bash
# Deploy Beacon to Fly.io
set -e

# Check flyctl is installed
if ! command -v fly &>/dev/null; then
    echo "flyctl not found. Install: curl -L https://fly.io/install.sh | sh"
    exit 1
fi

# Check auth
if ! fly auth whoami &>/dev/null; then
    echo "Not logged in. Run: fly auth login"
    exit 1
fi

APP_NAME="beacon-hai"

# Check if app already exists
if fly apps list | grep -q "$APP_NAME"; then
    echo "Deploying update to $APP_NAME..."
    fly deploy
else
    echo "Creating app $APP_NAME..."
    fly launch --no-deploy --copy-config --name "$APP_NAME" --region dfw
    # Allocate a dedicated IPv4 for WebRTC UDP
    echo "Allocating dedicated IPv4 (needed for WebRTC)..."
    fly ips allocate-v4
    echo "Deploying..."
    fly deploy
fi

echo ""
echo "Beacon is live at: https://$APP_NAME.fly.dev"
echo "  Streamer: https://$APP_NAME.fly.dev/go.html"
echo "  Viewer:   https://$APP_NAME.fly.dev/watch.html"
echo "  Status:   https://$APP_NAME.fly.dev/status"
