#!/usr/bin/env bash
set -euo pipefail

# — Configuration
ORG=${ORG:-arunsajukurian}
IMAGE_NAME=${IMAGE_NAME:-ollama-cpu}
TAG=${TAG:-latest}
PLATFORMS=${PLATFORMS:-"linux/arm64,linux/amd64"}
BUILDER_NAME="${BUILDER_NAME:-multiarch-builder}"
LOAD="${LOAD:-false}"

# — Optional Docker Hub login
if [[ -n "${DOCKER_USERNAME:-}" && -n "${DOCKER_PASSWORD:-}" ]]; then
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  ORG="$DOCKER_USERNAME"
fi

# Set up buildx if needed
BUILDER_NAME="multiarch-builder"
if ! docker buildx inspect ${BUILDER_NAME} &>/dev/null; then
    echo "Creating new buildx builder: ${BUILDER_NAME}"
    docker buildx create --name ${BUILDER_NAME} --driver docker-container --use
else
    docker buildx use ${BUILDER_NAME}
fi
docker buildx inspect --bootstrap

docker run --rm --privileged tonistiigi/binfmt --install aarch64,arm64


# Set PUSH to a non-empty string to trigger push instead of load
PUSH=${PUSH:-""}
if [ -z "${PUSH}" ] ; then
    echo "Building ${ORG}/${IMAGE_NAME}:${TAG} locally. Set PUSH=1 to push"
    # Note: --load only works for single platform, so if building locally, adjust PLATFORMS
    if [[ "${PLATFORMS}" == *","* ]]; then
        echo "WARNING: --load only works for single platform. Setting platform to linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"
        PLATFORMS="linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"
    fi
    LOAD_OR_PUSH="--load"
else
    echo "Will be pushing ${ORG}/${IMAGE_NAME}:${TAG}"
    LOAD_OR_PUSH="--push"
fi

echo "PLATFORMS: $PLATFORMS"

# — Build & push/load 
BUILD_CMD=(
  docker buildx build 
    --network host 
    --progress=plain 
    --builder $BUILDER_NAME 
    ${LOAD_OR_PUSH} 
    --platform $PLATFORMS 
    -f Dockerfile.cpu -t 
    ${ORG}/${IMAGE_NAME}:${TAG} 
    .
)

"${BUILD_CMD[@]}"
