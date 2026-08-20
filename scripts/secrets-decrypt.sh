#!/usr/bin/env bash
# Decrypt an encrypted Secret manifest to stdout (plaintext never touches disk).
# Usage: scripts/secrets-decrypt.sh envs/local/secrets/db.secret.yaml.enc
set -euo pipefail

KEY="${SECRETS_MASTER_KEY:-secrets/master.key}"
in="${1:?usage: secrets-decrypt.sh <secret.yaml.enc>}"

[ -f "$KEY" ] || { echo "master key not found: $KEY" >&2; exit 1; }
[ -f "$in" ]  || { echo "input not found: $in" >&2; exit 1; }

openssl enc -d -aes-256-cbc -pbkdf2 -in "$in" -pass "file:$KEY"
