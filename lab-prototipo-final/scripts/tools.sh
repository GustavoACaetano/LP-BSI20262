#!/usr/bin/env bash
# Optional local CLI installation with official release checksums. No sudo.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo 'Instalador para Linux.' >&2; exit 1; }
case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo 'Arquitetura não suportada.' >&2; exit 1 ;;
esac
mkdir -p "$ROOT/.state/bin"
tmp="$(mktemp -d "$ROOT/.state/tools.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
fetch() { curl --fail --silent --show-error --location --max-time 120 "$1" -o "$tmp/$2"; }
verify() {
  local expected actual
  expected="$(awk 'NR==1 {print $1}' "$tmp/$2")"
  actual="$(sha256sum "$tmp/$1" | awk '{print $1}')"
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ && "$actual" == "$expected" ]] || { echo "Checksum inválido: $1" >&2; exit 1; }
}
fetch "https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-$arch" kind
fetch "https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-$arch.sha256sum" kind.sum
verify kind kind.sum
fetch "https://dl.k8s.io/release/v1.34.0/bin/linux/$arch/kubectl" kubectl
fetch "https://dl.k8s.io/release/v1.34.0/bin/linux/$arch/kubectl.sha256" kubectl.sum
verify kubectl kubectl.sum
fetch "https://get.helm.sh/helm-v3.19.0-linux-$arch.tar.gz" helm.tar.gz
fetch "https://get.helm.sh/helm-v3.19.0-linux-$arch.tar.gz.sha256sum" helm.sum
verify helm.tar.gz helm.sum
tar -xzf "$tmp/helm.tar.gz" -C "$tmp" "linux-$arch/helm"
fetch "https://github.com/cilium/hubble/releases/download/v1.20.2/hubble-linux-$arch.tar.gz" hubble.tar.gz
fetch "https://github.com/cilium/hubble/releases/download/v1.20.2/hubble-linux-$arch.tar.gz.sha256sum" hubble.sum
verify hubble.tar.gz hubble.sum
tar -xzf "$tmp/hubble.tar.gz" -C "$tmp" hubble
install -m 755 "$tmp/kind" "$tmp/kubectl" "$tmp/hubble" "$ROOT/.state/bin/"
install -m 755 "$tmp/linux-$arch/helm" "$ROOT/.state/bin/helm"
echo 'Ferramentas instaladas apenas em .state/bin; make e scripts usam esse diretório.'
