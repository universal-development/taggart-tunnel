#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-./tt-chain.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

: "${LOCAL_PORT:?Missing LOCAL_PORT}"
: "${REMOTE_PORT:?Missing REMOTE_PORT}"
: "${HOST_CHAIN:?Missing HOST_CHAIN array}"

# Build -J jump chain (skip last, it's the target)
JUMP_CHAIN=""
for ((i = 0; i < ${#HOST_CHAIN[@]} - 1; i++)); do
  JUMP_CHAIN+="${HOST_CHAIN[i]},"
done
JUMP_CHAIN="${JUMP_CHAIN%,}"

TARGET_HOST="${HOST_CHAIN[-1]}"

echo "➡ Forwarding localhost:${LOCAL_PORT} → ${TARGET_HOST}:${REMOTE_PORT} via: $JUMP_CHAIN"
ssh -L "${LOCAL_PORT}:localhost:${REMOTE_PORT}" -J "$JUMP_CHAIN" "$TARGET_HOST"
