#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---------------------------------------------------------------
err() { printf '❌ %s\n' "$*" >&2; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
info() { printf '➜ %s\n' "$*"; }
die() { err "$*"; exit 1; }

# --- input/config ----------------------------------------------------------
CONFIG_FILE="${1:-./tt-chain.conf}"
[[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${LOCAL_PORT:?Missing LOCAL_PORT}"
: "${REMOTE_HOST:?Missing REMOTE_HOST}"
: "${REMOTE_PORT:?Missing REMOTE_PORT}"

# Validate HOST_CHAIN as non-empty Bash array
if ! declare -p HOST_CHAIN >/dev/null 2>&1; then
  die "Missing HOST_CHAIN array"
fi
case "$(declare -p HOST_CHAIN)" in
  declare\ -a*) ;;
  *) die "HOST_CHAIN must be a Bash array, e.g. HOST_CHAIN=(user@host:22|~/.ssh/key)" ;;
esac
(( ${#HOST_CHAIN[@]} > 0 )) || die "HOST_CHAIN is empty"

command -v ssh >/dev/null 2>&1 || die "ssh not found in PATH"

# --- temp ssh config -------------------------------------------------------
TMP_SSH_CONFIG=$(mktemp)
trap 'rm -f "$TMP_SSH_CONFIG"' EXIT

# Global defaults to improve tunnel reliability and avoid hostkey prompts
{
  echo "Host *"
  echo "  ExitOnForwardFailure yes"
  echo "  ServerAliveInterval 60"
  echo "  ServerAliveCountMax 3"
} >> "$TMP_SSH_CONFIG"

ALIASES=()
HOP_DESCRIPTIONS=()

# Build SSH config entries for each hop alias
for i in "${!HOST_CHAIN[@]}"; do
  entry="${HOST_CHAIN[$i]}"
  [[ -n "$entry" ]] || die "Empty HOST_CHAIN entry at index $i"

  IFS='|' read -r userhostport key <<< "$entry"
  IFS='@' read -r user hostport <<< "$userhostport"
  [[ -n "${user:-}" && -n "${hostport:-}" ]] || die "Invalid HOST_CHAIN[$i]: expected user@host[:port][|key]"
  IFS=':' read -r host port <<< "$hostport"
  port="${port:-22}"
  [[ "$port" =~ ^[0-9]+$ ]] || die "Invalid port for HOST_CHAIN[$i]: $port"

  alias="hop${i}"
  ALIASES+=("$alias")

  # expand ~ in key path if provided
  if [[ -n "${key:-}" ]]; then
    [[ "$key" == ~* ]] && key="${key/#\~/$HOME}"
    if [[ ! -f "$key" ]]; then
      warn "Identity file not found for $alias: $key"
    else
      # warn on loose permissions
      perm=$(stat -c '%a' "$key" 2>/dev/null || echo "")
      if [[ -n "$perm" && "$perm" != "600" && "$perm" != "400" ]]; then
        warn "Identity file permissions for $key are $perm (recommend 600)"
      fi
    fi
  fi

  {
    echo "Host $alias"
    echo "  HostName $host"
    echo "  User $user"
    echo "  Port $port"
    [[ -n "${key:-}" ]] && echo "  IdentityFile \"$key\""
    echo "  IdentitiesOnly yes"
    echo "  StrictHostKeyChecking no"
    echo "  UserKnownHostsFile /dev/null"
  } >> "$TMP_SSH_CONFIG"

  desc="$alias = ${user}@${host}:${port}"
  if [[ -n "${key:-}" ]]; then
    desc+=" (key: $key)"
  fi
  HOP_DESCRIPTIONS+=("$desc")
done

# Determine final host and optional jump chain for -J
NUM_HOPS=${#ALIASES[@]}
FINAL_ALIAS="${ALIASES[$((NUM_HOPS-1))]}"
JUMP_CHAIN=""
if (( NUM_HOPS > 1 )); then
  mapfile -t _jump_aliases < <(printf '%s\n' "${ALIASES[@]:0:$((NUM_HOPS-1))}")
  JUMP_CHAIN=$(IFS=, ; printf '%s' "${_jump_aliases[*]}")
fi

# --- logging ---------------------------------------------------------------
info "Forwarding localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_PORT}"
info "Hops (${NUM_HOPS}):"
for j in "${!HOP_DESCRIPTIONS[@]}"; do
  printf '   [%d] %s\n' "$j" "${HOP_DESCRIPTIONS[$j]}"
done
echo
echo "SSH command:"
if [[ -n "$JUMP_CHAIN" ]]; then
  echo "  ssh -F $TMP_SSH_CONFIG -J $JUMP_CHAIN -o ExitOnForwardFailure=yes -N -L ${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} $FINAL_ALIAS"
else
  echo "  ssh -F $TMP_SSH_CONFIG -o ExitOnForwardFailure=yes -N -L ${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} $FINAL_ALIAS"
fi
echo

# --- execute ---------------------------------------------------------------
if [[ -n "$JUMP_CHAIN" ]]; then
  ssh -F "$TMP_SSH_CONFIG" \
    -J "$JUMP_CHAIN" \
    -o ExitOnForwardFailure=yes \
    -N \
    -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" \
    "$FINAL_ALIAS"
else
  ssh -F "$TMP_SSH_CONFIG" \
    -o ExitOnForwardFailure=yes \
    -N \
    -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" \
    "$FINAL_ALIAS"
fi
