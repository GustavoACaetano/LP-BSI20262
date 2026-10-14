#!/usr/bin/env bash
# Lê os fluxos HTTP (L7) registrados pelo Hubble e classifica cada requisição
# pelo User-Agent: agente de IA autodeclarado ou tráfego comum.
#
# Uso: ./metricas-agentes-ia.sh [janela] [label-destino]
#   janela        período observado (padrão: 5m)
#   label-destino label do pod de destino (padrão: app=frontend)
#
# Requer: hubble CLI, jq e "cilium hubble port-forward" em execução.

set -euo pipefail

JANELA="${1:-5m}"
DESTINO="${2:-app=frontend}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Monta uma regex a partir da lista de tokens (uma linha por agente).
REGEX_IA="$(grep -v '^\s*$' "$DIR/agentes-ia.txt" | paste -sd '|' -)"

hubble observe \
  --since "$JANELA" \
  --type l7 \
  --protocol http \
  --to-label "$DESTINO" \
  -o jsonpb |
jq -rs --arg re "$REGEX_IA" '
  def pct($n; $total): if $total == 0 then 0 else ($n * 10000 / $total | round / 100) end;
  [ .[]
    | .flow
    | select(.l7.type == "REQUEST")
    | ( [ .l7.http.headers[]? | select(.key | ascii_downcase == "user-agent") | .value ][0] // "(sem user-agent)" ) as $ua
    | { ua: $ua, agente: ( ($ua | [match($re; "i").string][0]) // null ) }
  ] as $reqs
  | ($reqs | length) as $total
  | ($reqs | map(select(.agente != null)) ) as $ia
  | ($ia | length) as $n_ia
  | "Requisições HTTP observadas: \($total)",
  "  Agentes de IA autodeclarados: \($n_ia) (\(pct($n_ia; $total))%)",
  "  Demais clientes:              \($total - $n_ia) (\(pct($total - $n_ia; $total))%)",
  "",
  "Requisições por agente de IA:",
  ( $ia | group_by(.agente | ascii_downcase) | sort_by(-length)[]
    | "  \(.[0].agente): \(length)" ),
  "",
  "Requisições de demais clientes (por User-Agent):",
  ( $reqs | map(select(.agente == null)) | group_by(.ua) | sort_by(-length)[]
    | "  \(length)\t\(.[0].ua)" )
'
