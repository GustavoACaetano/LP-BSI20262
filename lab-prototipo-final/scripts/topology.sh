#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLAB="$ROOT/.state/bin/containerlab"
TOPO="$ROOT/infra/clients.clab.yaml"
KIND_NODE=agent-trap-lab-control-plane

usage() { echo "Uso: $0 {up|test|down}" >&2; exit 2; }
[[ $# == 1 ]] || usage
action="$1"
[[ "$action" == up || "$action" == test || "$action" == down ]] || usage

[[ -x "$CLAB" ]] || { echo "Containerlab executável ausente: $CLAB" >&2; exit 1; }
command -v sudo >/dev/null 2>&1 || { echo "sudo é obrigatório para Containerlab e Docker." >&2; exit 1; }
[[ -s "$TOPO" ]] || { echo "Topologia ausente: $TOPO" >&2; exit 1; }

inspect_kind_node() {
  sudo docker inspect "$KIND_NODE" >/dev/null || {
    echo "Node kind $KIND_NODE não encontrado; crie o cluster agent-trap-lab primeiro." >&2
    return 1
  }
  local networks
  networks="$(sudo docker inspect --format '{{json .NetworkSettings.Networks}}' "$KIND_NODE")"
  [[ "$networks" == *'"kind"'* ]] || {
    echo "$KIND_NODE não está conectado à rede Docker kind existente." >&2
    return 1
  }
  sudo docker network inspect kind >/dev/null || {
    echo "Rede Docker kind não encontrada; recusando criar ou substituir rede." >&2
    return 1
  }
}

kind_node_ip() {
  local ip
  ip="$(sudo docker inspect --format '{{with index .NetworkSettings.Networks "kind"}}{{.IPAddress}}{{end}}' "$KIND_NODE")"
  [[ -n "$ip" ]] || { echo "IP do node kind não disponível na rede kind." >&2; return 1; }
  printf '%s\n' "$ip"
}

case "$action" in
  up)
    inspect_kind_node
    sudo docker image inspect agent-trap-lab:local >/dev/null || {
      echo "Imagem agent-trap-lab:local ausente; construa a imagem antes." >&2
      exit 1
    }
    sudo "$CLAB" deploy --topo "$TOPO"
    ;;
  test)
    inspect_kind_node
    client_container=clab-agent-trap-clients-client
    reference_container=clab-agent-trap-clients-reference
    sudo docker inspect "$client_container" >/dev/null || { echo "Cliente containerlab não está ativo; execute topology.sh up." >&2; exit 1; }
    sudo docker inspect "$reference_container" >/dev/null || { echo "Referência containerlab não está ativa; execute topology.sh up." >&2; exit 1; }
    base="http://$(kind_node_ip):30080"
    sudo docker exec "$client_container" python /smoke.py --base "$base" --user-agent 'LabContainerlabClient/1.0'
    sudo docker exec "$reference_container" python /smoke.py --base "$base" --user-agent 'GPTBot/1.0'
    ;;
  down)
    sudo "$CLAB" destroy --topo "$TOPO" --keep-mgmt-net
    ;;
esac
