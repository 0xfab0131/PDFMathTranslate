#!/bin/sh
set -eu

RUNTIME_HOME="${HOME:-/state/home}"
RUNTIME_CACHE_DIR="${RUNTIME_HOME}/.cache"
RUNTIME_BABELDOC_CACHE="${RUNTIME_CACHE_DIR}/babeldoc"
IMAGE_BABELDOC_CACHE="/opt/babeldoc-assets/babeldoc"

mkdir -p "${RUNTIME_CACHE_DIR}"

# Keep translation/runtime data volatile while reusing the prewarmed
# static BabelDOC assets baked into the image.
if [ ! -e "${RUNTIME_BABELDOC_CACHE}" ]; then
  ln -s "${IMAGE_BABELDOC_CACHE}" "${RUNTIME_BABELDOC_CACHE}"
fi

exec "$@"
