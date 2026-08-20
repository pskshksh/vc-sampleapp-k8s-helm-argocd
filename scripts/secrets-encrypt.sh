#!/usr/bin/env bash
# Encrypt a plaintext Secret manifest with the local master key (AES-256-CBC).
# Usage: scripts/secrets-encrypt.sh envs/local/secrets/db.secret.yaml
# Produces <file>.enc alongside it (safe to commit).
set -euo pipefail

KEY="${SECRETS_MASTER_KEY:-secrets/master.key}"
in="${1:?usage: secrets-encrypt.sh <plaintext-secret.yaml>}"
out="${in}.enc"

[ -f "$KEY" ] || { echo "master key not found: $KEY (run scripts/secrets-keygen.sh)" >&2; exit 1; }
[ -f "$in" ]  || { echo "input not found: $in" >&2; exit 1; }

openssl enc -aes-256-cbc -pbkdf2 -salt -in "$in" -out "$out" -pass "file:$KEY"
echo "encrypted -> $out"
