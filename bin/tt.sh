#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-./tt-chain.conf}"
[[ -f "$CONFIG_FILE" ]] || { echo "❌ Config file not found: $CONFIG_FILE"; exit 1; }

source "$CONFIG_FILE"

: "${LOCAL_PORT:?Missing LOCAL_PORT}"
: "${REMOTE_HOST:?Missing REMOTE_HOST}"
: "${REMOTE_PORT:?Missing REMOTE_PORT}"
: "${HOST_CHAIN:?Missing HOST_CHAIN array}"

TMP_SSH_CONFIG=$(mktemp)
trap 'rm -f "$TMP_SSH_CONFIG"' EXIT

ALIASES=()
NUM_HOPS="${#HOST_CHAIN[@]}"

# Build SSH config with ProxyJump logic inside config
for i in "${!HOST_CHAIN[@]}"; do
  entry="${HOST_CHAIN[$i]}"
  IFS='|' read -r userhostport key <<< "$entry"
  IFS='@' read -r user hostport <<< "$userhostport"
  IFS=':' read -r host port <<< "$hostport"
  port="${port:-22}"
  alias="hop${i}"
  ALIASES+=("$alias")

  {
    echo "Host $alias"
    echo "  HostName $host"
    echo "  User $user"
    echo "  Port $port"
    [[ -n "${key:-}" ]] && echo "  IdentityFile $key"
    echo "  IdentitiesOnly yes"
    echo "  StrictHostKeyChecking no"
    # If not first, add ProxyJump to previous
    if [[ "$i" -gt 0 ]]; then
      prev_alias="hop$((i-1))"
      echo "  ProxyJump $prev_alias"
    fi
  } >> "$TMP_SSH_CONFIG"
done

FINAL="${ALIASES[-1]}"

echo "➡ Forwarding localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_PORT} via:"
for alias in "${ALIASES[@]}"; do
  grep -A6 "Host $alias" "$TMP_SSH_CONFIG" | sed 's/^/    /'
done
echo
echo "🚀 Executing SSH with:"
echo "    ssh -F $TMP_SSH_CONFIG -N -L ${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} $FINAL"
echo

ssh -F "$TMP_SSH_CONFIG" \
  -N \
  -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" \
  "$FINAL"
