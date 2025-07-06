#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-./tt-chain.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"

: "${LOCAL_PORT:?Missing LOCAL_PORT}"
: "${REMOTE_HOST:?Missing REMOTE_HOST}"
: "${REMOTE_PORT:?Missing REMOTE_PORT}"
: "${HOST_CHAIN:?Missing HOST_CHAIN array}"

TMP_SSH_CONFIG=$(mktemp)
trap 'rm -f "$TMP_SSH_CONFIG"' EXIT

JUMP_CHAIN=""
for i in "${!HOST_CHAIN[@]}"; do
  raw_entry="${HOST_CHAIN[$i]}"
  IFS='|' read -r connection key <<< "$raw_entry"

  # Default values
  user=""
  host=""
  port="22"

  # Parse connection: user@host:port or host:port
  if [[ "$connection" == *"@"* ]]; then
    user_host="${connection%@*}"
    host_port="${connection#*@}"
  else
    user_host=""
    host_port="$connection"
  fi

  user="${user_host:-$USER}"

  if [[ "$host_port" == *":"* ]]; then
    host="${host_port%%:*}"
    port="${host_port##*:}"
  else
    host="$host_port"
  fi

  alias_name="hop${i}_${host//[^a-zA-Z0-9]/_}_${port}"

  {
    echo "Host $alias_name"
    echo "  HostName $host"
    echo "  Port $port"
    echo "  User $user"
    [[ -n "${key:-}" ]] && echo "  IdentityFile $key"
    echo "  IdentitiesOnly yes"
    echo "  StrictHostKeyChecking no"
  } >> "$TMP_SSH_CONFIG"

  if [[ $i -lt $((${#HOST_CHAIN[@]} - 1)) ]]; then
    JUMP_CHAIN+="$alias_name,"
  fi
done

JUMP_CHAIN="${JUMP_CHAIN%,}"

# Use last hop as SSH target for port forwarding
last_index=$((${#HOST_CHAIN[@]} - 1))
last_entry="${HOST_CHAIN[$last_index]}"
IFS='|' read -r last_connection _ <<< "$last_entry"
if [[ "$last_connection" == *":"* ]]; then
  last_host="${last_connection%%:*}"
  last_port="${last_connection##*:}"
else
  last_host="$last_connection"
  last_port="22"
fi
last_alias="hop${last_index}_${last_host//[^a-zA-Z0-9]/_}_${last_port}"

echo "➡ Forwarding localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_PORT} via: $JUMP_CHAIN"

ssh -F "$TMP_SSH_CONFIG" \
    -N \
    -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" \
    -J "$JUMP_CHAIN" \
    "$last_alias"
