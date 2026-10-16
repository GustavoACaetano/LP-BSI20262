#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/.state/bin:$PATH"
STATE="$ROOT/.state"
CLUSTER=agent-trap-lab
KUBECONFIG="$STATE/kubeconfig"
mkdir -p "$STATE/node-data" "$STATE/node-data/trap" "$STATE/node-data/prometheus" "$STATE/node-data/grafana"
chmod 700 "$STATE" "$STATE/node-data"
export HELM_CONFIG_HOME="$STATE/helm-config"
export HELM_CACHE_HOME="$STATE/helm-cache"
export HELM_DATA_HOME="$STATE/helm-data"

for command in docker kind kubectl helm openssl rg sed; do
  command -v "$command" >/dev/null 2>&1 || { echo "Comando obrigatório ausente: $command" >&2; exit 1; }
done
docker info >/dev/null

if [[ -e "$KUBECONFIG" ]]; then
  context="$(kubectl --kubeconfig "$KUBECONFIG" config current-context 2>/dev/null || true)"
  [[ "$context" == "kind-$CLUSTER" ]] || { echo "Kubeconfig existente não pertence ao contexto kind-$CLUSTER; recusando substituir." >&2; exit 1; }
  kubectl --kubeconfig "$KUBECONFIG" cluster-info >/dev/null || { echo "Cluster existente não responde; examine .state antes de continuar." >&2; exit 1; }
else
  if kind get clusters | rg -qx "$CLUSTER"; then
    echo "Cluster $CLUSTER já existe sem o kubeconfig isolado esperado; recusando adoção/substituição." >&2
    exit 1
  fi
  sed "s|__NODE_DATA_PATH__|$STATE/node-data|g" "$ROOT/infra/kind.yaml" >"$STATE/kind.yaml"
  # Nodes only become Ready after installing Cilium; do not wait for CNI here.
  kind create cluster --config "$STATE/kind.yaml" --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
  chmod 600 "$KUBECONFIG"
fi

helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update cilium
helm upgrade --install cilium cilium/cilium --version 1.20.2 \
  --namespace kube-system --kubeconfig "$KUBECONFIG" \
  -f "$ROOT/infra/cilium-values.yaml" --wait --timeout 10m

# Helm can return before the operator has registered Cilium CRDs.
kubectl --kubeconfig "$KUBECONFIG" -n kube-system rollout status daemonset/cilium --timeout=600s
kubectl --kubeconfig "$KUBECONFIG" wait --for=condition=Established crd/ciliumnetworkpolicies.cilium.io --timeout=180s

docker build -t agent-trap-lab:local "$ROOT"
kind load docker-image agent-trap-lab:local --name "$CLUSTER"

kubectl --kubeconfig "$KUBECONFIG" apply -f "$ROOT/infra/workloads.yaml"
kubectl --kubeconfig "$KUBECONFIG" apply -f "$ROOT/infra/observability.yaml"
password_file="$STATE/grafana-admin-password"
if [[ ! -s "$password_file" ]]; then
  umask 077
  openssl rand -base64 32 >"$password_file"
  chmod 600 "$password_file"
fi
kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab create secret generic grafana-admin \
  --from-file=password="$password_file" --dry-run=client -o yaml |
  kubectl --kubeconfig "$KUBECONFIG" apply -f - >/dev/null
dashboard="$ROOT/infra/grafana/dashboard.json"
[[ -s "$dashboard" ]] || { echo "Dashboard esperado ausente: $dashboard" >&2; exit 1; }
kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab create configmap grafana-dashboard \
  --from-file=dashboard.json="$dashboard" --dry-run=client -o yaml |
  kubectl --kubeconfig "$KUBECONFIG" apply -f - >/dev/null

# Same local image tag and subPath ConfigMaps require a new pod on reapply.
kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab rollout restart deployment/trap deployment/prometheus deployment/grafana

kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab rollout status deployment/trap --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab rollout status deployment/prometheus --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" -n agent-trap-lab rollout status deployment/grafana --timeout=180s
kubectl --kubeconfig "$KUBECONFIG" -n kube-system rollout status daemonset/cilium --timeout=180s
echo "Lab pronto. App em http://127.0.0.1:18080; use make grafana, make prometheus ou make hubble-ui para port-forward."
