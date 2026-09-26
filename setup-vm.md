# Cilium Lab — Preparação da Máquina Virtual

Este guia continua a configuração iniciada em [`install-vm.md`](./install-vm.md), após a instalação do Ubuntu Server e o primeiro login na máquina virtual.

---

## 1. Atualizar o sistema

Após reiniciar a máquina e fazer login no Ubuntu, atualize a lista de pacotes e os pacotes instalados:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 2. Instalar ferramentas básicas

Instale as ferramentas que serão utilizadas durante o laboratório:

```bash
sudo apt install -y \
  curl \
  wget \
  git \
  vim \
  jq \
  net-tools \
  iproute2 \
  iputils-ping \
  dnsutils \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https
```

---

## 3. Instalar o Docker

### Criar o diretório de chaves do APT

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

### Adicionar a chave oficial do Docker

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### Adicionar o repositório do Docker

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Atualizar os repositórios

```bash
sudo apt update
```

### Instalar o Docker Engine e plugins

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

### Adicionar o usuário ao grupo `docker`

```bash
sudo usermod -aG docker $USER
```

> Após adicionar o usuário ao grupo `docker`, encerre a sessão e faça login novamente para que a alteração tenha efeito.

---

## 4. Instalar o kind

Baixe o executável do **kind**:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
```

Dê permissão de execução:

```bash
chmod +x ./kind
```

Mova o executável para `/usr/local/bin`:

```bash
sudo mv ./kind /usr/local/bin/kind
```

Verifique a instalação:

```bash
kind version
```

---

## 5. Criar o cluster Kubernetes

Crie um cluster local utilizando o kind:

```bash
kind create cluster
```

---

## 6. Instalar o Cilium CLI

Obtenha a versão estável atual do Cilium CLI:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
```

Defina a arquitetura da máquina:

```bash
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
```

Baixe o Cilium CLI e o arquivo de checksum:

```bash
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

Valide o arquivo baixado:

```bash
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
```

Instale o binário em `/usr/local/bin`:

```bash
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
```

Remova os arquivos utilizados na instalação:

```bash
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

---

## 7. Instalar o Cilium

Instale o Cilium no cluster Kubernetes:

```bash
cilium install 1.20.2
```

---

## 8. Habilitar o Hubble

Habilite o Hubble no cluster:

```bash
cilium hubble enable
```

---

## 9. Instalar o kubectl

No Ubuntu, instale o cliente do Kubernetes:

```bash
sudo apt update
sudo apt install -y kubectl
```

Se preferir usar a instalação oficial do repositório do Kubernetes, também é possível seguir este procedimento:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl
```

---

## 10. Instalar o Hubble CLI

Instale o cliente do Hubble para inspecionar fluxos de rede do cluster:

```bash
sudo apt update

sudo apt install -y kubectl

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)

HUBBLE_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi

curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum

sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin

rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

> Esse comando instala o binário `hubble` e deixa o cliente pronto para uso.

---

## 11. Laboratório de protótipo inicial

A parte de criação da infraestrutura do primeiro laboratório foi separada em uma pasta dedicada para manter o guia principal de instalação mais enxuto.

Consulte a pasta [lab-prototipo-inicial](lab-prototipo-inicial) e siga os passos documentados em [lab-prototipo-inicial/README.md](lab-prototipo-inicial/README.md).

Nessa pasta você encontrará os arquivos:

- [lab-prototipo-inicial/lab-app.yaml](lab-prototipo-inicial/lab-app.yaml)
- [lab-prototipo-inicial/lab-services.yaml](lab-prototipo-inicial/lab-services.yaml)
- [lab-prototipo-inicial/policy.yaml](lab-prototipo-inicial/policy.yaml)

Você pode validar a infraestrutura com os comandos abaixo:

```bash
kubectl get pods
kubectl get svc
kubectl get cnp
```

Se tudo estiver correto, a infraestrutura do protótipo já pode ser observada com Hubble e Cilium.
