#!/usr/bin/env bash
# Keep VM access independent from the SSH connection used for deployment.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
services=(agent-trap-http agent-trap-grafana agent-trap-prometheus agent-trap-hubble-ui)
[[ "$EUID" == 0 ]] || { echo "Execute com sudo: $0 install IP_PRIVADO | stop | start | status" >&2; exit 1; }
action="${1:-}"
case "$action" in
  install)
    bind="${2:?Informe o IP privado da VM}"
    python3 - "$bind" <<'PY'
import ipaddress,sys
address=ipaddress.ip_address(sys.argv[1])
assert address.version == 4 and address.is_private and not address.is_unspecified
PY
    owner="${SUDO_USER:-gabriel}"
    id "$owner" >/dev/null
    [[ -x "$ROOT/.state/bin/kubectl" && -s "$ROOT/.state/kubeconfig" ]] || { echo 'Suba o cluster primeiro.' >&2; exit 1; }
    command -v socat >/dev/null
    for name in "${services[@]}"; do
      case "$name" in
        agent-trap-http) command_line="/usr/bin/socat TCP-LISTEN:18080,bind=$bind,reuseaddr,fork TCP:127.0.0.1:18080" ;;
        agent-trap-grafana) command_line="$ROOT/.state/bin/kubectl --kubeconfig $ROOT/.state/kubeconfig -n agent-trap-lab port-forward --address=127.0.0.1,$bind svc/grafana 13000:3000" ;;
        agent-trap-prometheus) command_line="$ROOT/.state/bin/kubectl --kubeconfig $ROOT/.state/kubeconfig -n agent-trap-lab port-forward --address=127.0.0.1,$bind svc/prometheus 19090:9090" ;;
        agent-trap-hubble-ui) command_line="$ROOT/.state/bin/kubectl --kubeconfig $ROOT/.state/kubeconfig -n kube-system port-forward --address=127.0.0.1,$bind svc/hubble-ui 18081:80" ;;
      esac
      cat >"/etc/systemd/system/$name.service" <<EOF
[Unit]
Description=Agent trap laboratory access - $name
After=network-online.target docker.service
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$owner
WorkingDirectory=$ROOT
ExecStart=$command_line
Restart=always
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
    done
    systemctl daemon-reload
    systemctl enable "${services[@]/%/.service}"
    systemctl restart "${services[@]/%/.service}"
    ;;
  stop) systemctl disable --now "${services[@]/%/.service}" ;;
  start) systemctl enable --now "${services[@]/%/.service}" ;;
  status) systemctl --no-pager --full status "${services[@]/%/.service}" ;;
  *) echo "Uso: sudo $0 install IP_PRIVADO | stop | start | status" >&2; exit 2 ;;
esac
