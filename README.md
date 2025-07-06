# taggart-tunnel
TaggartTunnel is a lightweight, configurable SSH port forwarding tool that chains multiple jump hosts to securely access internal services.


## Example configuration


```
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