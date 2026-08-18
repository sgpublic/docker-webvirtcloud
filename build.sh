#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE="${IMAGE:-sgpublic/docker-webvirtcloud}"
DOCKERFILE="${DOCKERFILE:-docker/Dockerfile}"
CONTEXT="${CONTEXT:-.}"
PUSH="${PUSH:-1}"

# Ensure the webvirtcloud submodule is present
if [ ! -f webvirtcloud/manage.py ]; then
  echo "Initializing webvirtcloud submodule..."
  git submodule update --init --recursive
fi

# Resolve the exact commit id of the webvirtcloud submodule (the code being built)
COMMIT="$(git -C webvirtcloud rev-parse HEAD 2>/dev/null || true)"
if [ -z "$COMMIT" ]; then
  COMMIT="$(git submodule status webvirtcloud 2>/dev/null | awk '{print $1}' | tr -d '+- ')"
fi
if [ -z "$COMMIT" ] || [ "${#COMMIT}" -ne 40 ]; then
  echo "ERROR: could not determine webvirtcloud submodule commit id" >&2
  exit 1
fi

FULL_IMAGE="${REGISTRY}/${IMAGE}"
echo "Building ${FULL_IMAGE} (webvirtcloud commit ${COMMIT})"

# Authenticate to the registry if credentials are provided
if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_ACTOR:-}" ]; then
  echo "${GITHUB_TOKEN}" | docker login "${REGISTRY}" -u "${GITHUB_ACTOR}" --password-stdin
elif [ -n "${GHCR_TOKEN:-}" ]; then
  docker login "${REGISTRY}" -u "${GHCR_USER:-sgpublic}" --password-stdin <<< "${GHCR_TOKEN}"
fi

docker build -f "${DOCKERFILE}" \
  -t "${FULL_IMAGE}:${COMMIT}" \
  -t "${FULL_IMAGE}:latest" \
  "${CONTEXT}"

if [ "${PUSH}" = "1" ]; then
  docker push "${FULL_IMAGE}:${COMMIT}"
  docker push "${FULL_IMAGE}:latest"
  echo "Pushed:"
  echo "  ${FULL_IMAGE}:${COMMIT}"
  echo "  ${FULL_IMAGE}:latest"
fi
