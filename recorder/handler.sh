#!/bin/sh
# Recording handler — called by socat for each HTTP connection.
# Manages an FFmpeg process that pulls RTMP from MediaMTX and saves to MP4.

MEDIAMTX_HOST="${MEDIAMTX_HOST:-mediamtx}"
MEDIAMTX_URL="rtmp://${MEDIAMTX_HOST}:1935/live"
RECORDING_DIR="${RECORDING_DIR:-/recordings}"
PID_FILE="/tmp/recorder.pid"
META_FILE="/tmp/recorder.meta"

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
            respond '{"active":true,"message":"already recording"}'
        else
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            FILENAME="beacon-${TIMESTAMP}.mp4"
            FILEPATH="${RECORDING_DIR}/${FILENAME}"

            ffmpeg -loglevel warning \
                -i "$MEDIAMTX_URL" \
                -c copy \
                -movflags +frag_keyframe+empty_moov \
                "$FILEPATH" </dev/null >/dev/null 2>&1 &
            echo $! > "$PID_FILE"
            echo "${FILENAME}" > "$META_FILE"
            sleep 1
            if is_running; then
                respond "{\"active\":true,\"filename\":\"${FILENAME}\",\"message\":\"recording started\"}"
            else
                rm -f "$PID_FILE" "$META_FILE"
                respond '{"active":false,"error":"recording failed — is a stream live?"}'
            fi
        fi
        ;;
    /stop)
        if is_running; then
            kill "$(cat "$PID_FILE")" 2>/dev/null || true
            sleep 1
            FILENAME=""
            [ -f "$META_FILE" ] && FILENAME=$(cat "$META_FILE")
            rm -f "$PID_FILE" "$META_FILE"
            respond "{\"active\":false,\"filename\":\"${FILENAME}\",\"message\":\"recording stopped\"}"
        else
            rm -f "$PID_FILE" "$META_FILE" 2>/dev/null
            respond '{"active":false,"message":"not recording"}'
        fi
        ;;
    /status)
        if is_running; then
            FILENAME=""
            [ -f "$META_FILE" ] && FILENAME=$(cat "$META_FILE")
            respond "{\"active\":true,\"filename\":\"${FILENAME}\"}"
        else
            rm -f "$PID_FILE" "$META_FILE" 2>/dev/null
            respond '{"active":false}'
        fi
        ;;
    /list)
        # Build JSON array of recordings with name and size
        FILES="["
        FIRST=true
        for f in "${RECORDING_DIR}"/*.mp4; do
            [ -f "$f" ] || continue
            NAME=$(basename "$f")
            SIZE=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "0")
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                FILES="${FILES},"
            fi
            FILES="${FILES}{\"name\":\"${NAME}\",\"size\":${SIZE}}"
        done
        FILES="${FILES}]"
        respond "{\"recordings\":${FILES}}"
        ;;
    *)
        printf "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
        ;;
esac
