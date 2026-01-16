#!/bin/bash
# Local build script for self21 Docker container
# Source: https://gitlab.com/HttpAnimations/self21 (Rust 2024 Edition)

set -e

# Configuration
GITLAB_REPO="https://gitlab.com/HttpAnimations/self21.git"
IMAGE_NAME="${IMAGE_NAME:-self21}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SOURCE_DIR="./self21-source"
BRANCH="${BRANCH:-master}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Docker container for self21 (Rust 2024 Edition)"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME       Image name (default: self21)"
    echo "  -t, --tag TAG         Image tag (default: latest)"
    echo "  -b, --branch BRANCH   Git branch to build (default: master)"
    echo "  -p, --push            Push to registry after build"
    echo "  -r, --registry REG    Registry to push to (default: none)"
    echo "  --platform PLATFORM   Target platform (default: linux/amd64)"
    echo "  --no-cache            Build without cache"
    echo "  --clean               Remove source directory after build"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Basic build"
    echo "  $0 -t v1.0.0                    # Build with specific tag"
    echo "  $0 -p -r ghcr.io/user/self21    # Build and push to GHCR"
    echo "  $0 --platform linux/amd64,linux/arm64  # Multi-platform build"
}

# Parse arguments
PUSH=false
REGISTRY=""
PLATFORM="linux/amd64"
NO_CACHE=""
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check for Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check for Docker Buildx (for multi-platform builds)
if [[ "$PLATFORM" == *","* ]]; then
    if ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is required for multi-platform builds"
        exit 1
    fi
fi

print_status "Building self21 Docker image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Source:   ${GITLAB_REPO}"
echo "  Branch:   ${BRANCH}"
echo "  Image:    ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Platform: ${PLATFORM}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clone or update source
if [ -d "$SOURCE_DIR" ]; then
    print_status "Updating existing source directory..."
    cd "$SOURCE_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    cd ..
else
    print_status "Cloning self21 repository..."
    git clone --depth 1 --branch "$BRANCH" "$GITLAB_REPO" "$SOURCE_DIR"
fi

# Get source commit hash
SOURCE_COMMIT=$(cd "$SOURCE_DIR" && git rev-parse --short HEAD)
print_status "Source commit: ${SOURCE_COMMIT}"

# Build image
print_status "Building Docker image..."

BUILD_ARGS=(
    --build-arg "BUILDTIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    --build-arg "VERSION=${IMAGE_TAG}"
    --build-arg "REVISION=${SOURCE_COMMIT}"
)

if [[ "$PLATFORM" == *","* ]]; then
    # Multi-platform build with buildx
    print_status "Using Docker Buildx for multi-platform build..."
    
    BUILDX_ARGS=(
        --platform "$PLATFORM"
        "${BUILD_ARGS[@]}"
        -t "${IMAGE_NAME}:${IMAGE_TAG}"
        -t "${IMAGE_NAME}:${SOURCE_COMMIT}"
    )
    
    if [ -n "$REGISTRY" ]; then
        BUILDX_ARGS+=(-t "${REGISTRY}:${IMAGE_TAG}")
        BUILDX_ARGS+=(-t "${REGISTRY}:${SOURCE_COMMIT}")
    fi
    
    if [ "$PUSH" = true ]; then
        BUILDX_ARGS+=(--push)
    else
        BUILDX_ARGS+=(--load)
        print_warning "Multi-platform builds with --load only loads the current platform image"
    fi
    
    docker buildx build $NO_CACHE "${BUILDX_ARGS[@]}" "$SOURCE_DIR"
else
    # Standard single-platform build
    docker build $NO_CACHE \
        "${BUILD_ARGS[@]}" \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -t "${IMAGE_NAME}:${SOURCE_COMMIT}" \
        "$SOURCE_DIR"
    
    if [ -n "$REGISTRY" ]; then
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}:${IMAGE_TAG}"
        docker tag "${IMAGE_NAME}:${SOURCE_COMMIT}" "${REGISTRY}:${SOURCE_COMMIT}"
    fi
    
    if [ "$PUSH" = true ] && [ -n "$REGISTRY" ]; then
        print_status "Pushing image to registry..."
        docker push "${REGISTRY}:${IMAGE_TAG}"
        docker push "${REGISTRY}:${SOURCE_COMMIT}"
    fi
fi

# Cleanup if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning up source directory..."
    rm -rf "$SOURCE_DIR"
fi

print_success "Build completed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Commit: ${SOURCE_COMMIT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run with:"
echo "  docker run -d -p 3000:3000 -v ./data:/data ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Or use docker-compose:"
echo "  IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${IMAGE_TAG} docker-compose up -d"
