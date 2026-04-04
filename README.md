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

## Recording

Beacon can record your stream to MP4 files on the server. Control it from the streamer UI while live.

### Setup

Recordings are saved to `./recordings` by default. To change the directory, set `RECORDING_DIR` in your `.env` file:

```
RECORDING_DIR=/path/to/recordings
```

Restart the recorder container if you change this: `docker compose up -d recorder`

### Usage

1. Open `https://your-domain/go.html` and tap **GO LIVE**.
2. A **Record** button appears below the main controls.
3. Tap it to start recording — the circle fills red and a timer shows elapsed time.
4. Tap again to stop recording. The MP4 file is saved to disk.
5. When you stop the main stream, any active recording stops automatically.

Files are named `beacon-YYYYMMDD-HHMMSS.mp4`.

### API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/recording/start` | POST | Start recording (creates timestamped MP4) |
| `/api/recording/stop` | POST | Stop recording and finalize file |
| `/api/recording/status` | GET | Check recording state (`active`, `filename`) |
| `/api/recording/list` | GET | List saved recordings (`name`, `size`) |

## Optional: Stream to YouTube Too

Beacon can relay your stream to YouTube Live in real time. You control it from the streamer UI — no restart required.

### Setup

1. Get a stream key from YouTube Studio (Go Live → Stream → Copy stream key).
2. Add it to your `.env` file:
   ```
   YOUTUBE_STREAM_KEY=xxxx-xxxx-xxxx-xxxx
   ```
3. Restart the relay container: `docker compose up -d youtube-relay`

### Usage

1. Open `https://your-domain/go.html` and tap **GO LIVE** as usual.
2. A **YouTube** toggle button appears below the main controls.
3. Tap it to start relaying to YouTube — a red dot confirms it's active.
4. Tap again to stop the YouTube relay (your self-hosted stream continues).
5. When you stop the main stream, the YouTube relay stops automatically.

### API

You can also control the relay programmatically:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/youtube/start` | POST | Start relaying to YouTube |
| `/api/youtube/stop` | POST | Stop relaying to YouTube |
| `/api/youtube/status` | GET | Check relay state (`active`, `configured`) |

## Architecture

```
Phone browser ──WHIP/WebRTC──▶ MediaMTX ──HLS──▶ nginx ──▶ Viewer browser
                                  │
                           youtube-relay (FFmpeg)
                                  │
                                  └──RTMP──▶ YouTube (toggle on/off)
                                  │
                            recorder (FFmpeg)
                                  │
                                  └──RTMP──▶ MP4 on disk (toggle on/off)
```

- **MediaMTX** handles WebRTC ingest (WHIP) and HLS output
- **nginx** reverse-proxies everything behind SSL, serves the PWA
- **youtube-relay** FFmpeg sidecar that pushes RTMP to YouTube on demand
- **recorder** FFmpeg sidecar that saves the stream to MP4 on demand
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
