# 🧭 TaggartTunnel

**TaggartTunnel** is a lightweight, secure, and configurable SSH port forwarding tool designed to traverse multiple
SSH jump hosts and securely access internal, non-public services (such as RDP, databases, or web apps).

---

## 🚀 Features

- 🔐 **Secure multi-hop SSH tunneling**
- 🔧 **Per-host configuration**: user, port, and identity file
- 🧱 **Supports non-SSH services** (RDP, HTTP, DBs)
- ⚡ **Fully self-contained Bash script** (no extra tools required)
- 🪵 **Debug-friendly logging** to show tunnel structure and command

---

## ⚡ Quick Start

1) Copy and edit the example config:
   - `cp example-tt-chain.conf tt-chain.conf`
   - Set `LOCAL_PORT`, `REMOTE_HOST`, `REMOTE_PORT`, and your `HOST_CHAIN`.

2) Run the tunnel:
   - With Task: `task run CONFIG=./tt-chain.conf`
   - Direct script: `bin/tt.sh ./tt-chain.conf`

3) Connect to your local port (e.g., `localhost:4000`). Press Ctrl+C to stop.

The script prints the hop chain and final SSH command for visibility.

---

## 📁 Configuration Format

You define the port forwarding route using a `.conf` file:

```bash
# project1.conf

LOCAL_PORT=4000
REMOTE_HOST=192.168.10.10
REMOTE_PORT=3389

# Format: user@host[:port][|optional_key_path]
HOST_CHAIN=(
  ubuntu@jump1.example.com:22|~/.ssh/jump1.pem
  ubuntu@jump2.internal:22|~/.ssh/jump2.pem
)

```

---

## 📦 Dependencies

- Runtime: `bash` (POSIX shell), `ssh` client, `mktemp` (coreutils), and access to your SSH keys.
- Optional (development): `task` (https://taskfile.dev), `shellcheck` (lint), `shfmt` (format). These improve contributor workflow but are not required to run the tunnel.

Install Task if you plan to use the provided `Taskfile.yml` tasks: see https://taskfile.dev/#/installation.

---

## 📝 License

This project is licensed under the MIT License. See the `LICENSE` file for details.
