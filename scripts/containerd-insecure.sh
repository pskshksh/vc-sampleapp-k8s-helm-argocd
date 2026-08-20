#!/usr/bin/env bash
# Configure the Lima k8s node's containerd to pull from the local registry over
# plain HTTP (localhost:30082). Additive + reversible: drops a conf.d import and
# a certs.d host file, then restarts containerd. Run once per node.
set -euo pipefail

VM="${LIMA_VM:-k8s}"
# Configure both endpoints so the node can pull whether the image ref uses
# 127.0.0.1 or localhost.
ENDPOINTS="${REGISTRY_ENDPOINTS:-127.0.0.1:30082 localhost:30082}"

# Point containerd's CRI registry at the certs.d directory (idempotent).
limactl shell "$VM" -- sudo mkdir -p /etc/containerd/conf.d
limactl shell "$VM" -- sudo tee /etc/containerd/conf.d/registry.toml >/dev/null <<'EOF'
[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
EOF

# Per-registry host config: plain HTTP, skip TLS verify.
for REG in $ENDPOINTS; do
  limactl shell "$VM" -- sudo mkdir -p "/etc/containerd/certs.d/$REG"
  limactl shell "$VM" -- sudo tee "/etc/containerd/certs.d/$REG/hosts.toml" >/dev/null <<EOF
server = "http://$REG"
[host."http://$REG"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
done

limactl shell "$VM" -- sudo systemctl restart containerd
echo "containerd on '$VM' configured for insecure registries: $ENDPOINTS (restarted)"
