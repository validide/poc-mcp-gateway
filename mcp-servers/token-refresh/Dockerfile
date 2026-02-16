FROM alpine:3.21

RUN apk add --no-cache curl

COPY refresh.sh /usr/local/bin/refresh.sh
RUN chmod +x /usr/local/bin/refresh.sh

# Create shared dir owned by non-root user so volume writes work
RUN adduser -D -u 1000 tokenuser && \
    mkdir -p /shared && chown tokenuser:tokenuser /shared

USER tokenuser

ENTRYPOINT ["/usr/local/bin/refresh.sh"]
