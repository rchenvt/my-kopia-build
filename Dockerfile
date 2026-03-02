# Build the thin Alpine-based image
FROM alpine:3.23

# Install dependencies required for HA sync and Kopia operations
# - ca-certificates: Required for cloud storage/HTTPS connectivity
# - fuse3: Required if you intend to use 'kopia mount'
# - tzdata: For consistent snapshot timestamps
RUN apk add --no-cache \
    tar \
    unzip \
    curl \
    sshfs \
    ca-certificates \
    fuse3 \
    tzdata

RUN KOPIA_ARCH=$( [ "$TARGETARCH" = "amd64" ] && echo "x64" || echo "arm64" ) && \
    LATEST_KOPIA_TAG=$(curl -s https://api.github.com/repos/kopia/kopia/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') && \
    curl -L "https://github.com/kopia/kopia/releases/download/v{LATEST_KOPIA_TAG}/kopia-${LATEST_KOPIA_TAG}-linux-${KOPIA_ARCH}.tar.gz" \
    | tar -xz -C /bin/ --strip-components=1 "kopia-${LATEST_KOPIA_TAG}-linux-${KOPIA_ARCH}/kopia" && \
    chmod +x /bin/kopia

# Rclone provides a 'current' link that always points to the latest stable release
RUN curl -L "https://downloads.rclone.org/rclone-current-linux-{TARGETARCH}.zip" -o rclone.zip && \
    unzip rclone.zip && \
    cp rclone-*-linux-${TARGETARCH}/rclone /bin/rclone && \
    chmod +x /bin/rclone && \
    rm -rf rclone.zip rclone-*-linux-${TARGETARCH}

RUN apk del tar unzip && rm -rf /var/cache/apk/*

# Create the alpine user/group (UID/GID 1000) for your setup
RUN addgroup -g 1000 kopia && \
    adduser -u 1000 -G kopia -D kopia

# Replicate the official directory structure
RUN mkdir -p /app/config /app/cache /app/logs /repository  && \
    chown -R kopia:kopia /app /repository

# Set official environment variables used by Kopia's entrypoint logic
ENV TERM="xterm-256color" \
    LC_ALL="C.UTF-8" \
    KOPIA_CONFIG_PATH=/app/config/repository.config \
    KOPIA_LOG_DIR=/app/logs \
    KOPIA_CACHE_DIRECTORY=/app/cache \
    RCLONE_CONFIG=/app/rclone/rclone.conf \
    KOPIA_PERSIST_CREDENTIALS_ON_CONNECT=false \
    KOPIA_CHECK_FOR_UPDATES=false

# Expose the standard Kopia API port
EXPOSE 51515

# Use the official user context
USER kopia
WORKDIR /app

# Replicate the official Entrypoint and default Command
ENTRYPOINT ["/bin/kopia"]
