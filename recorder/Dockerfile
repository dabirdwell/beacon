FROM alpine:latest
RUN apk add --no-cache ffmpeg socat
RUN mkdir -p /recordings
COPY handler.sh /handler.sh
RUN chmod +x /handler.sh
EXPOSE 8080
CMD ["socat", "TCP-LISTEN:8080,reuseaddr,fork", "EXEC:/handler.sh"]
