#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node_ip="$("$ROOT/scripts/node-ip.sh")"
# A separate Docker container, outside the Kubernetes cluster. Not an LLM.
docker run --rm --network kind \
  --mount "type=bind,src=$ROOT/tools/smoke.py,dst=/smoke.py,readonly" \
  agent-trap-lab:local python /smoke.py --base "http://$node_ip:30080" "$@"
