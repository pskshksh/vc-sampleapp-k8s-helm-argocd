#!/usr/bin/env bash
# Decrypt an encrypted Secret manifest and apply it to the cluster in one step.
# The plaintext is streamed to kubectl and never written to disk.
# Usage: scripts/secrets-apply.sh envs/local/secrets/db.secret.yaml.enc
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
in="${1:?usage: secrets-apply.sh <secret.yaml.enc>}"

"$here/secrets-decrypt.sh" "$in" | kubectl apply -f -
