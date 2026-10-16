#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -s "$ROOT/.state/kubeconfig" ]] || { echo "Execute scripts/up.sh primeiro." >&2; exit 1; }
node="agent-trap-lab-control-plane"
ip="$(docker inspect --format '{{with index .NetworkSettings.Networks "kind"}}{{.IPAddress}}{{end}}' "$node")"
[[ -n "$ip" ]] || { echo "Não foi possível obter o IP Docker de $node." >&2; exit 1; }
printf '%s\n' "$ip"
echo "Clientes conectados à rede Docker kind acessam http://$ip:30080" >&2
