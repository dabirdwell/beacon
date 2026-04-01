# Beacon Deployment Guide

## Local Deployment (Mac Studio / Home Server)

### Prerequisites
- Docker Desktop installed
- Port 80 and 443 available

### Steps

```bash
git clone https://github.com/humanityandai/beacon.git
cd beacon
docker compose up -d
```

Local mode skips SSL — access at `http://localhost`.

For local testing without a domain, create a `.env` with:
```
DOMAIN=localhost
EMAIL=you@example.com
ADMIN_PASSWORD=changeme
YOUTUBE_KEY=
```

Generate the auth file:
```bash
docker run --rm httpd:alpine htpasswd -nb admin changeme > nginx/.htpasswd
```

Then start:
```bash
docker compose up -d
```

- Streamer PWA: `http://localhost/go.html`
- Viewer: `http://localhost/watch.html`
- Landing page: `http://localhost/`

> **Note:** WebRTC requires HTTPS in most browsers. Local testing works on `localhost` (browsers allow it as a special case), but external access requires SSL.

---

## VPS Deployment (DigitalOcean / Linode / Any VPS)

### 1. Provision a VPS

- **OS:** Ubuntu 22.04+ or Debian 12+
- **RAM:** 1 GB minimum (2 GB recommended)
- **CPU:** 1 vCPU is fine
- **Ports:** Open 80, 443 (TCP), and 8189 (UDP + TCP) in your firewall

### 2. Install Docker

```bash
ssh root@your-server-ip

# Install Docker
curl -fsSL https://get.docker.com | sh
```

### 3. Clone and Configure

```bash
git clone https://github.com/humanityandai/beacon.git
cd beacon
bash setup.sh
```

The setup script will prompt for:
- **Domain name** (e.g., `beacon.humanityandai.com`)
- **Email** (for Let's Encrypt SSL)
- **Admin password** (for the `/status` endpoint)
- **YouTube stream key** (optional)

It handles SSL certificates, WebRTC NAT configuration, and starts all containers.

### 4. Verify

```bash
docker compose ps          # All containers should be "Up"
curl -I https://your-domain/  # Should return 200
```

---

## Domain Setup: beacon.humanityandai.com

### DNS Configuration

1. Log into your DNS provider (Cloudflare, Namecheap, etc.)
2. Add an **A record**:
   - **Name:** `beacon` (or `@` for root domain)
   - **Value:** Your VPS IP address
   - **TTL:** Auto or 300
3. Wait for propagation (usually 1–5 minutes, can take up to 48 hours)

### Verify DNS

```bash
dig beacon.humanityandai.com +short
# Should return your VPS IP
```

### Then Run Setup

```bash
ssh root@your-vps-ip
cd beacon
bash setup.sh
# Enter: beacon.humanityandai.com when prompted for domain
```

The setup script will:
- Verify DNS resolution
- Obtain a Let's Encrypt SSL certificate via certbot
- Configure nginx as a reverse proxy with SSL
- Configure WebRTC NAT traversal with your public IP
- Start all services

---

## Architecture in Production

```
Phone browser ──HTTPS──▶ nginx (443)
                           ├── /           → Landing page
                           ├── /go.html    → Streamer PWA
                           ├── /watch.html → HLS viewer
                           ├── /live/whip  → MediaMTX WHIP (WebRTC ingest)
                           ├── /live/      → MediaMTX HLS (video segments)
                           └── /status     → MediaMTX API (auth required)

Phone camera ──WebRTC/UDP──▶ MediaMTX (8189) ──HLS──▶ nginx ──▶ Viewers
                                │
                                └──RTMP──▶ YouTube (optional)
```

---

## Testing

### 1. WHIP Publish from Phone

1. Open `https://beacon.humanityandai.com/go.html` on your phone
2. Allow camera and microphone permissions
3. Tap **GO LIVE**
4. You should see:
   - Camera preview fullscreen behind the UI
   - Red pulsing LIVE indicator
   - Stream stats (duration, bandwidth, health)
   - Share link and QR code

### 2. HLS Playback in Browser

1. Open `https://beacon.humanityandai.com/watch.html` on any device
2. The player should connect and show the live stream
3. Expect 5–10 seconds of latency (HLS buffering)

### 3. Stream Health Check

```bash
# Check if a stream is active (requires admin password)
curl -u admin:yourpassword https://beacon.humanityandai.com/status
```

### 4. Container Logs

```bash
docker compose logs -f mediamtx   # Video server logs
docker compose logs -f nginx      # Proxy logs
docker compose logs -f app        # Static file server logs
```

---

## Maintenance

### SSL Certificate Renewal

Certbot runs in a container and auto-renews every 12 hours. No action needed.

### Updating Beacon

```bash
cd beacon
git pull
docker compose down
docker compose up -d
```

### Restarting

```bash
docker compose restart
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| WebRTC won't connect | Check port 8189 UDP is open in firewall |
| SSL certificate fails | Verify DNS points to this server, port 80 is open |
| Stream starts but viewer sees nothing | Wait 10s for HLS segments to build up |
| Camera permission denied | Must use HTTPS (or localhost) |
| YouTube relay not working | Check RTMP port 1935 is open, verify stream key |
