# Beacon

A self-hosted, one-button live streaming tool for communities and civic groups. One technical person sets it up; everyone else taps a button.

## What You Need

- **A server** — any VPS or home server running Docker (Ubuntu, Debian, etc. — 1 GB RAM is plenty).
- **A domain name** — something like `stream.yourgroup.org`, with DNS pointed at your server's IP address.

## Setup

1. Clone this repo onto your server:
   ```
   git clone https://github.com/humanityandai/beacon.git
   cd beacon
   ```

2. Run the setup script:
   ```
   bash setup.sh
   ```

3. Enter your domain name, email, and an admin password when prompted.

4. The script handles SSL certificates, WebRTC configuration, and starts everything automatically.

5. That's it. Beacon is running.

## How to Go Live

1. Open `https://your-domain/go.html` on your phone.
2. Tap **GO LIVE**.

Your camera and microphone activate, and the stream starts immediately. A share link and QR code appear on screen.

Use the camera toggle button (top-right) to switch between front and rear cameras without interrupting the stream.

## How to Share the Stream

Send anyone the viewer link: `https://your-domain/watch.html`

They open it in any browser — no app needed, no account needed. They're watching.

## Optional: Stream to YouTube Too

If you want your stream to simultaneously go to YouTube:

1. Get a stream key from YouTube Studio (Go Live > Stream > Copy stream key).
2. Open your `.env` file and paste it into the `YOUTUBE_KEY=` line.
3. Re-run `bash setup.sh` or restart: `docker compose restart`

Your stream now goes to both your self-hosted server and YouTube at the same time.

## Architecture

```
Phone browser ──WHIP/WebRTC──▶ MediaMTX ──HLS──▶ nginx ──▶ Viewer browser
                                  │
                                  └──RTMP──▶ YouTube (optional)
```

- **MediaMTX** handles WebRTC ingest (WHIP) and HLS output
- **nginx** reverse-proxies everything behind SSL, serves the PWA
- **certbot** manages Let's Encrypt SSL certificates
- WebRTC media flows over a single muxed UDP port (8189)

## Quick Deploy: Fly.io

No server needed — deploy Beacon to Fly.io's edge network.

### Prerequisites
- [flyctl](https://fly.io/docs/flyctl/install/) installed
- Fly.io account (`fly auth login`)

### Deploy

```bash
bash deploy.sh
```

This creates a single-container app (`beacon-hai` in Dallas) with:
- Fly handling SSL termination (HTTPS automatic)
- MediaMTX + nginx combined in one container
- WebRTC UDP port exposed for streaming

After deploy:
- **Streamer:** `https://beacon-hai.fly.dev/go.html`
- **Viewer:** `https://beacon-hai.fly.dev/watch.html`
- **Status:** `https://beacon-hai.fly.dev/status`

> **Note:** WebRTC requires a dedicated IPv4 for reliable UDP media delivery. The deploy script allocates one automatically ($2/mo on Fly.io). If WebRTC publishing doesn't work, verify with `fly ips list`.

## Advanced: Home Assistant Integration

Beacon exposes a `/status` endpoint so Home Assistant can detect when a stream is live. This lets you trigger automations — notify trusted contacts, change lighting, log events.

Add a REST sensor to your HA configuration:

```yaml
sensor:
  - platform: rest
    name: beacon_live
    resource: "https://stream.yourgroup.org/status"
    authentication: basic
    username: admin
    password: !secret beacon_password
    value_template: "{{ value_json.itemCount > 0 }}"
```

The status endpoint is protected by the admin password you set during setup.

## Getting Help

- [Open an issue](https://github.com/humanityandai/beacon/issues) if you run into problems.
- Learn more at [humanityandai.com](https://humanityandai.com).

## License

MIT — see [LICENSE](LICENSE).
