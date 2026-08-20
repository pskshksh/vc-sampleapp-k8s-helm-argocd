#!/usr/bin/env bash
# Generate the local symmetric master key used to encrypt/decrypt secret files.
# Keep this file safe and OFF git. Store a backup in a password manager.
set -euo pipefail

KEY="${SECRETS_MASTER_KEY:-secrets/master.key}"

if [ -f "$KEY" ]; then
  echo "refusing to overwrite existing key: $KEY" >&2
  exit 1
fi

mkdir -p "$(dirname "$KEY")"
openssl rand -base64 48 > "$KEY"
chmod 600 "$KEY"
echo "master key written -> $KEY"
echo "KEEP IT SAFE. NEVER COMMIT IT. Anyone with this key can read every secret."
