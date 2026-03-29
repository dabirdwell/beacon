#!/bin/sh
set -e

# Resolve public IP for WebRTC NAT traversal
# Fly.io machines need this so browsers can send media to MediaMTX
PUBLIC_IP="${FLY_PUBLIC_IP:-$(wget -qO- https://ifconfig.me 2>/dev/null || echo "")}"

if [ -n "$PUBLIC_IP" ]; then
    sed -i "s/webrtcICEHostNAT1To1IPs: \[\]/webrtcICEHostNAT1To1IPs: [$PUBLIC_IP]/" /etc/mediamtx/mediamtx.yml
    echo "WebRTC NAT IP: $PUBLIC_IP"
fi

# Start MediaMTX in background
/usr/local/bin/mediamtx /etc/mediamtx/mediamtx.yml &

# Start nginx in foreground (PID 1 for health checks)
exec nginx -g 'daemon off;'
