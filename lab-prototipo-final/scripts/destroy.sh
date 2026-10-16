#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${1:-}" == "--confirm" && $# == 1 ]] || { echo "Uso: $0 --confirm (remove somente o cluster kind agent-trap-lab)" >&2; exit 2; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/.state/bin:$PATH"
STATE="$ROOT/.state"
KUBECONFIG="$STATE/kubeconfig"
if [[ -e "$KUBECONFIG" ]]; then
  context="$(kubectl --kubeconfig "$KUBECONFIG" config current-context 2>/dev/null || true)"
  [[ "$context" == "kind-agent-trap-lab" ]] || { echo "Kubeconfig não corresponde ao cluster esperado; recusando exclusão." >&2; exit 1; }
fi
if command -v kind >/dev/null 2>&1 && kind get clusters | rg -qx agent-trap-lab; then
  kind delete cluster --name agent-trap-lab
fi
rm -f "$KUBECONFIG"
echo "Cluster kind agent-trap-lab removido; estado persistente local mantido em .state/node-data."
