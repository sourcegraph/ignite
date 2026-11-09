#!/usr/bin/env bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [manifest-list] [arch0...n]"
    exit 1
fi

set -euxo pipefail

IMAGE=${1}
shift
read -r -a DOCKER <<< "${DOCKER:-docker}"
IMAGES=()

for arch in "$@"; do
    "${DOCKER[@]}" push "${IMAGE}-${arch}"
    IMAGES+=("${IMAGE}-${arch}")
done

# Architecture tags can themselves be indexes containing provenance attestations.
"${DOCKER[@]}" buildx imagetools create --tag "${IMAGE}" "${IMAGES[@]}"
