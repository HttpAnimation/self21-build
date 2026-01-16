# Build stage - Using Rust nightly for zune-jpeg 0.5.8 which requires rustc 1.87+
FROM rust:1.85-bookworm AS builder

WORKDIR /app

# Install build dependencies and switch to nightly
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/* \
    && rustup default nightly \
    && rustup update nightly

# Copy manifests first for better caching
COPY Cargo.toml Cargo.lock ./

# Create dummy src to build dependencies
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs

# Build dependencies (cached layer)
RUN cargo build --release && rm -rf src

# Copy actual source code
COPY src ./src
COPY templates ./templates
COPY static ./static

# Touch main.rs to invalidate the cache for source code
RUN touch src/main.rs

# Build the actual application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 self21

# Copy the binary from builder
COPY --from=builder /app/target/release/self21 /app/self21

# Copy static files and templates
COPY --from=builder /app/templates /app/templates
COPY --from=builder /app/static /app/static

# Environment variables for configurable paths
ENV DATABASE_PATH=/data/database
ENV MEDIA_PATH=/data/media
ENV RUST_LOG=self21=info,tower_http=info

# Create data directories
RUN mkdir -p /data/database /data/media/originals /data/media/thumbnails /data/media/samples && \
    chown -R self21:self21 /app /data

# Create entrypoint script that handles directory creation and drops to non-root user
COPY --chmod=755 <<'EOF' /app/entrypoint.sh
#!/bin/bash
set -e

# Ensure directories exist (runs as root)
mkdir -p "${DATABASE_PATH}"
mkdir -p "${MEDIA_PATH}/originals"
mkdir -p "${MEDIA_PATH}/thumbnails"
mkdir -p "${MEDIA_PATH}/samples"

# Fix ownership for mounted volumes
chown -R self21:self21 "${DATABASE_PATH}" "${MEDIA_PATH}"

# Create symlinks if they don't exist
[ ! -L /app/database ] && ln -sf "${DATABASE_PATH}" /app/database
[ ! -L /app/media ] && ln -sf "${MEDIA_PATH}" /app/media

# Drop privileges and run as self21 user
exec gosu self21 "$@"
EOF

# Install gosu for dropping privileges
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# Run as root initially (entrypoint will drop to self21)
# USER self21

# Expose default port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/metrics || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/self21"]
