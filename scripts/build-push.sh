#!/usr/bin/env bash
# Build the three app images and publish them to the in-cluster registry,
# tagged with ./VERSION.
#
# macOS reality: podman runs in its own VM and can't reach the Lima registry's
# host-loopback NodePort, and the Lima VM doesn't mount the source. So we:
#   1. build with podman on the host
#   2. stream the image into the Lima VM (podman save | nerdctl load, ns=default)
#   3. push to the registry from INSIDE Lima, where localhost:30082 works
# Loading into the `default` namespace (not k8s.io) keeps the node's image store
# clean, so pods genuinely PULL from the registry at deploy time.
#
#   scripts/build-push.sh                 # uses defaults below
#   TAG=0.2.0 scripts/build-push.sh
set -euo pipefail

REGISTRY="${REGISTRY:-127.0.0.1:30082/docker-local}"
APP_REPO="${APP_REPO:-../vc-sampleapp-go-rust-react}"
TAG="${TAG:-$(cat "$(dirname "$0")/../VERSION")}"
ENGINE="${ENGINE:-podman}"
LIMA_VM="${LIMA_VM:-k8s}"

publish() {
  local name="$1" ctx="$2" ref="$REGISTRY/$1:$TAG"
  echo ">> [$1] building $ref"
  "$ENGINE" build -t "$ref" "$APP_REPO/$ctx"
  echo ">> [$1] streaming into Lima ($LIMA_VM) and pushing to the registry"
  "$ENGINE" save "$ref" | limactl shell "$LIMA_VM" -- sudo nerdctl -n default load
  limactl shell "$LIMA_VM" -- sudo nerdctl -n default push --insecure-registry "$ref"
}

publish goapi     services/goapi
publish rscounter services/rscounter
publish webapp    js

echo "done. Published goapi/rscounter/webapp :$TAG to $REGISTRY"
