#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/.state/bin:$PATH"
STATE="$ROOT/.state"
KUBECONFIG="$STATE/kubeconfig"
[[ -s "$KUBECONFIG" ]] || { echo "Execute scripts/up.sh primeiro." >&2; exit 1; }
command -v hubble >/dev/null 2>&1 || { echo "Instale hubble CLI no host para capturar eventos." >&2; exit 1; }
[[ "$(kubectl --kubeconfig "$KUBECONFIG" config current-context)" == "kind-agent-trap-lab" ]] || { echo "Contexto inesperado no kubeconfig isolado." >&2; exit 1; }
mkdir -p "$STATE"
capture="$STATE/hubble.jsonl"
port_pid=""
cleanup() {
  if [[ -n "$port_pid" ]]; then
    kill -TERM "$port_pid" 2>/dev/null || true
    wait "$port_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM
kubectl --kubeconfig "$KUBECONFIG" -n kube-system port-forward svc/hubble-relay 4245:80 >"$STATE/hubble-port-forward.log" 2>&1 &
port_pid=$!
ready=0
for _ in $(seq 1 30); do
  if ! kill -0 "$port_pid" 2>/dev/null; then cat "$STATE/hubble-port-forward.log" >&2; exit 1; fi
  if (echo >/dev/tcp/127.0.0.1/4245) >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo "Hubble Relay não abriu localhost:4245; consulte .state/hubble-port-forward.log." >&2; exit 1; }
echo "Capturando Hubble L7 em $capture (Ctrl-C encerra); falhas do CLI aparecem no terminal."
hubble observe --server localhost:4245 --follow --namespace agent-trap-lab --type l7 --output jsonpb |
  tee -a "$capture"
