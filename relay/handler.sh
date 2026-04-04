#!/bin/sh
# YouTube relay handler — called by socat for each HTTP connection.
# Manages an FFmpeg process that pulls RTMP from MediaMTX and pushes to YouTube.

YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}"
MEDIAMTX_HOST="${MEDIAMTX_HOST:-mediamtx}"
MEDIAMTX_URL="rtmp://${MEDIAMTX_HOST}:1935/live"
PID_FILE="/tmp/relay.pid"

# Read HTTP request line
read -r REQUEST_LINE
METHOD=$(echo "$REQUEST_LINE" | tr -d '\r' | cut -d' ' -f1)
URL_PATH=$(echo "$REQUEST_LINE" | tr -d '\r' | cut -d' ' -f2)

# Consume remaining headers
while IFS= read -r header; do
    header=$(echo "$header" | tr -d '\r')
    [ -z "$header" ] && break
done

respond() {
    local body="$1"
    printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: POST, GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s" "${#body}" "$body"
}

is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# CORS preflight
if [ "$METHOD" = "OPTIONS" ]; then
    printf "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: POST, GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
    exit 0
fi

case "$URL_PATH" in
    /start)
        if is_running; then
            respond '{"active":true,"message":"already running"}'
        elif [ -z "$YOUTUBE_STREAM_KEY" ]; then
            respond '{"active":false,"error":"no stream key configured"}'
        else
            ffmpeg -loglevel warning -i "$MEDIAMTX_URL" -c copy -f flv "$YOUTUBE_URL" </dev/null >/dev/null 2>&1 &
            echo $! > "$PID_FILE"
            sleep 1
            if is_running; then
                respond '{"active":true,"message":"started"}'
            else
                rm -f "$PID_FILE"
                respond '{"active":false,"error":"relay failed — is a stream live?"}'
            fi
        fi
        ;;
    /stop)
        if is_running; then
            kill "$(cat "$PID_FILE")" 2>/dev/null || true
            rm -f "$PID_FILE"
        fi
        respond '{"active":false,"message":"stopped"}'
        ;;
    /status)
        configured="false"
        [ -n "$YOUTUBE_STREAM_KEY" ] && configured="true"
        if is_running; then
            respond "{\"active\":true,\"configured\":${configured}}"
        else
            rm -f "$PID_FILE" 2>/dev/null
            respond "{\"active\":false,\"configured\":${configured}}"
        fi
        ;;
    *)
        printf "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
        ;;
esac
