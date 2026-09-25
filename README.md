# Cilium Lab

Este repositório reúne o material de apoio para um laboratório de redes e políticas de comunicação em Kubernetes com Cilium.

A documentação e os arquivos do laboratório foram organizados em pastas e documentos específicos para deixar o fluxo mais claro:

- [install-vm.md](install-vm.md): criação e configuração inicial da máquina virtual Ubuntu
- [setup-vm.md](setup-vm.md): preparação da VM, instalação do Docker, kind, Cilium, Hubble e kubectl
- [lab-prototipo/README.md](lab-prototipo/README.md): guia do protótipo inicial do laboratório
- [lab-prototipo/lab-app.yaml](lab-prototipo/lab-app.yaml): manifest com os pods do laboratório
- [lab-prototipo/lab-services.yaml](lab-prototipo/lab-services.yaml): manifest com os Services do laboratório
- [lab-prototipo/policy.yaml](lab-prototipo/policy.yaml): política de rede do Cilium para limitar o acesso entre os pods

---

## Objetivo

O laboratório tem como objetivo demonstrar:

- criação de uma VM Ubuntu para ambiente de testes
- provisionamento de um cluster Kubernetes local com kind
- instalação do Cilium como CNI
- uso de Hubble para observabilidade de tráfego
- aplicação de políticas de rede com `CiliumNetworkPolicy`
- validação de comunicação entre serviços dentro do cluster

---

## Estrutura do repositório

```text
.
├── README.md
├── install-vm.md
├── setup-vm.md
├── lab-prototipo/
│   ├── README.md
│   ├── lab-app.yaml
│   ├── lab-services.yaml
│   └── policy.yaml
```

---

## Fluxo recomendado

1. Crie a máquina virtual seguindo o passo a passo em [install-vm.md](install-vm.md).
2. Prepare o ambiente e instale as ferramentas em [setup-vm.md](setup-vm.md).
3. Suba a infraestrutura do protótipo em [lab-prototipo/lab-app.yaml](lab-prototipo/lab-app.yaml) e [lab-prototipo/lab-services.yaml](lab-prototipo/lab-services.yaml).
4. Aplique a política de rede em [lab-prototipo/policy.yaml](lab-prototipo/policy.yaml).
5. Valide o comportamento com `kubectl` e `hubble`.

---

## Arquivos de laboratório

### Prototipo inicial

O diretório [lab-prototipo](lab-prototipo) concentra os arquivos do laboratório inicial:

- [lab-prototipo/lab-app.yaml](lab-prototipo/lab-app.yaml) cria os pods `frontend`, `backend` e `database`
- [lab-prototipo/lab-services.yaml](lab-prototipo/lab-services.yaml) expõe esses pods por meio de Services do tipo `ClusterIP`
- [lab-prototipo/policy.yaml](lab-prototipo/policy.yaml) define uma regra de rede do Cilium para permitir apenas que o pod `backend` acesse o pod `database`

---

## Observações

Este repositório foi organizado em documentos separados para deixar a instalação e a execução do laboratório mais legíveis e fáceis de seguir. O README agora funciona como índice geral do projeto, enquanto os outros arquivos concentram os passos detalhados e os manifests utilizados.
