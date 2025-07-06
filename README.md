# 🧭 TaggartTunnel

**TaggartTunnel** is a lightweight, secure, and configurable SSH port forwarding tool designed to traverse multiple
SSH jump hosts and securely access internal, non-public services (such as RDP, databases, or web apps).

---

## 🚀 Features

- 🔐 **Secure multi-hop SSH tunneling**
- 🔧 **Per-host configuration**: user, port, and identity file
- 🧱 **Supports non-SSH services** (RDP, HTTP, DBs)
- ❌ **Ignores SSH agent keys** using `IdentitiesOnly yes`
- ⚡ **Fully self-contained Bash script** (no extra tools required)
- 🪵 **Debug-friendly logging** to show tunnel structure and command

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
