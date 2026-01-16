# self21-build

Build scripts for [self21](https://gitlab.com/HttpAnimations/self21) - A self-hosted media server with e621 API compatibility.

Built with **Rust 2024 Edition**.

## Quick Start

### Using the build script

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/self21-build.git
cd self21-build

# Make the build script executable
chmod +x build.sh

# Build the Docker image
./build.sh

# Run with docker-compose
docker-compose up -d
```

### Manual Build

```bash
# Clone the source
git clone https://gitlab.com/HttpAnimations/self21.git

# Build the image
docker build -t self21:latest self21

# Run the container
docker run -d \
  -p 3000:3000 \
  -v ./data:/data \
  self21:latest
```

## Build Script Options

```bash
./build.sh [OPTIONS]

Options:
  -n, --name NAME       Image name (default: self21)
  -t, --tag TAG         Image tag (default: latest)
  -b, --branch BRANCH   Git branch to build (default: master)
  -p, --push            Push to registry after build
  -r, --registry REG    Registry to push to
  --platform PLATFORM   Target platform (default: linux/amd64)
  --no-cache            Build without cache
  --clean               Remove source directory after build
  -h, --help            Show help message
```

### Examples

```bash
# Basic build
./build.sh

# Build with specific tag
./build.sh -t v1.0.0

# Build and push to GitHub Container Registry
./build.sh -p -r ghcr.io/username/self21

# Multi-platform build (requires Docker Buildx)
./build.sh --platform linux/amd64,linux/arm64
```

## GitHub Actions

This repository includes a GitHub Actions workflow that:

1. Clones the source from GitLab
2. Builds the Docker image
3. Pushes to GitHub Container Registry (GHCR)

No secrets or variables need to be configured - it uses the automatic `GITHUB_TOKEN`.

## Environment Variables

When running the container, you can configure:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_PATH` | `/data/database` | Path to store the database |
| `MEDIA_PATH` | `/data/media` | Path to store media files |
| `RUST_LOG` | `self21=info` | Log level |

## Docker Compose

```yaml
# Simple usage
docker-compose up -d

# With custom configuration
PORT=8080 \
DATABASE_PATH=/custom/db \
MEDIA_PATH=/custom/media \
docker-compose up -d
```

## License

The build scripts are provided under the MIT License.

The self21 application is licensed under [GNU AGPLv3](https://gitlab.com/HttpAnimations/self21/-/blob/master/LICENSE).
