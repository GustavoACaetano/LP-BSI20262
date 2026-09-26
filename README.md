# Cilium Lab — Prototipação de observabilidade de rede em Kubernetes

Este repositório reúne os materiais de apoio para um projeto de pesquisa e prototipação em redes de Kubernetes com foco em Cilium, eBPF e observabilidade de tráfego. A proposta central do trabalho é explorar a ideia de metrificar o tráfego originado por agentes de IA, avaliando a viabilidade de monitorar e classificar fluxos de rede em ambientes containerizados.

A estrutura do projeto foi organizada para permitir:

- a criação de um ambiente local com Kubernetes usando kind
- a instalação e configuração do Cilium como CNI
- a observação de tráfego com Hubble
- a validação de políticas de rede e isolamento de serviços
- a evolução do protótipo para cenários mais próximos da proposta acadêmica

---

## Contexto do projeto

O tema do grupo foi definido como: "Metrificação do Tráfego Originado Por Agentes de IA".

A ideia parte da necessidade de entender como o tráfego gerado por sistemas autônomos, assistentes inteligentes ou agentes de IA se comporta dentro de um ambiente de microserviços e clusters Kubernetes. O uso de tecnologias baseadas em eBPF, como Cilium, oferece uma base natural para observar fluxos de rede em nível de kernel, com baixa sobrecarga e melhor visibilidade sobre comunicação entre containers e serviços.

O objetivo geral é avaliar se é possível construir um protótipo que permita:

- identificar fontes de tráfego gerado por agentes de IA
- observar padrões de comunicação entre serviços
- aplicar políticas de rede e isolamento
- coletar métricas de fluxo relevantes para análise e pesquisa

---

## Objetivo do laboratório

O laboratório tem como foco demonstrar, de forma prática, o funcionamento do Cilium em um cluster Kubernetes e preparar a base para a evolução da proposta de projeto. Em termos de escopo inicial, o repositório busca mostrar:

- criação de uma VM Ubuntu para ambiente de testes
- provisionamento de um cluster Kubernetes local com kind
- instalação do Cilium e do Hubble
- observabilidade de tráfego dentro do cluster
- aplicação de políticas de rede com CiliumNetworkPolicy
- validação de comunicação entre serviços em um ambiente simples

---

## Estrutura do repositório

```text
.
├── README.md
├── install-vm.md
├── setup-vm.md
├── lab-prototipo-inicial/
│   ├── README.md
│   ├── lab-app.yaml
│   ├── lab-services.yaml
│   └── policy.yaml
├── slides
│   ├── Proposta de Projeto - Lab Pesq.pptx
```

---

## Documentos principais

- [install-vm.md](install-vm.md): instruções para criar e configurar a máquina virtual Ubuntu
- [setup-vm.md](setup-vm.md): instalação de Docker, kind, kubectl, Cilium e Hubble
- [lab-prototipo-inicial/README.md](lab-prototipo-inicial/README.md): descrição do protótipo inicial do laboratório
- [lab-prototipo-inicial/lab-app.yaml](lab-prototipo-inicial/lab-app.yaml): manifest com os pods de exemplo do ambiente
- [lab-prototipo-inicial/lab-services.yaml](lab-prototipo-inicial/lab-services.yaml): serviços do cluster para comunicação interna
- [lab-prototipo-inicial/policy.yaml](lab-prototipo-inicial/policy.yaml): política de rede para limitar a comunicação entre pods
- [Proposta de Projeto - Lab Pesq.pptx](Proposta%20de%20Projeto%20-%20Lab%20Pesq.pptx): apresentação inicial da proposta do projeto

---

## Fluxo recomendado

1. Siga o passo a passo de criação da VM em [install-vm.md](install-vm.md).
2. Prepare o ambiente com as ferramentas em [setup-vm.md](setup-vm.md).
3. Acesse o diretório [lab-prototipo-inicial](lab-prototipo-inicial) e explore os manifests do protótipo inicial.
4. Suba os pods e serviços com os arquivos YAML do laboratório.
5. Aplique a política de rede e valide o comportamento com kubectl, Hubble e ferramentas de observabilidade do Cilium.
6. Evolve a solução para contemplar cenários mais próximos da proposta de metrificação de tráfego de agentes de IA.

---

## Prototipo inicial

O diretório [lab-prototipo-inicial](lab-prototipo-inicial) contém a base inicial do laboratório:

- [lab-prototipo-inicial/lab-app.yaml](lab-prototipo-inicial/lab-app.yaml) cria os pods `frontend`, `backend` e `database`
- [lab-prototipo-inicial/lab-services.yaml](lab-prototipo-inicial/lab-services.yaml) expõe a comunicação entre os serviços dentro do cluster
- [lab-prototipo-inicial/policy.yaml](lab-prototipo-inicial/policy.yaml) limita a comunicação para demonstrar a aplicação de políticas de rede com Cilium

Esse protótipo funciona como ponto de partida para validar conceitos essenciais de rede, isolamento e observabilidade. A partir dele, a proposta pode evoluir para cenários mais complexos, incluindo identificação e medição de tráfego associado a agentes de IA.

---

## Observação

Este repositório foi organizado para facilitar a reprodução do ambiente e a compreensão do problema de pesquisa. Em sua etapa inicial, ele funciona como laboratório técnico de referência para Cilium e eBPF; em sua evolução, pode se transformar em um protótipo acadêmico aplicado à métrificação de tráfego originado por agentes de IA.
