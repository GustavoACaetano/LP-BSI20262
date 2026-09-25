# Prototipo inicial do laboratório Cilium

Esta pasta reúne a base do protótipo inicial do projeto, criado para validar conceitos de rede, isolamento e observabilidade em Kubernetes com Cilium. A intenção é demonstrar, de forma simples e reproduzível, como políticas de rede e observação de tráfego podem ser aplicadas em um ambiente containerizado.

O cenário aqui implementado funciona como ponto de partida para a proposta mais ampla de metrificar o tráfego originado por agentes de IA. Antes de evoluir para esse cenário, o laboratório valida a infraestrutura básica em que a solução será construída.

---

## Objetivo do protótipo

Subir um ambiente mínimo com três pods e aplicar uma política de rede para demonstrar:

- comunicação entre serviços em um cluster Kubernetes
- uso do Cilium como CNI
- observabilidade de tráfego com Hubble
- isolamento de fluxos por política de rede

---

## Estrutura dos arquivos

- `lab-app.yaml`: definição dos pods do laboratório
- `lab-services.yaml`: definição dos Services para comunicação interna
- `policy.yaml`: política de rede do Cilium

---

## 1. Preparar o cluster

Antes de executar esta parte, certifique-se de que o cluster Kubernetes já está pronto e que o comando `kubectl` está funcionando:

```bash
kubectl get nodes
```

Se o comando retornar os nós do cluster, o ambiente está pronto para continuar.

---

## 2. Criar os pods

Aplique o manifesto dos pods:

```bash
kubectl apply -f lab-app.yaml
kubectl get pods -o wide
```

A saída esperada é semelhante a:

```text
NAME       READY   STATUS    IP           NODE
backend    1/1     Running   10.0.0.XX    ...
database   1/1     Running   10.0.0.XX    ...
frontend   1/1     Running   10.0.0.XX    ...
```

Os pods representam uma arquitetura simples de aplicação com camada de apresentação, processamento e dados.

---

## 3. Criar os Services

Aplique os serviços para permitir a comunicação interna:

```bash
kubectl apply -f lab-services.yaml
kubectl get svc
```

Saída esperada:

```text
NAME       TYPE        CLUSTER-IP
backend    ClusterIP   10.x.x.x
database   ClusterIP   10.x.x.x
frontend   ClusterIP   10.x.x.x
```

---

## 4. Aplicar a política de rede

Aplique a política do Cilium:

```bash
kubectl apply -f policy.yaml
```

O arquivo `policy.yaml` foi definido para permitir que o pod `backend` acesse o pod `database`, enquanto a comunicação fora da regra prevista fica bloqueada. Esse comportamento é essencial para validar o papel do Cilium na aplicação de políticas de rede no nível do cluster.

---

## 5. Comandos úteis

```bash
kubectl get pods
kubectl get svc
kubectl get cnp
kubectl describe pod backend
kubectl describe pod database
```

Também é útil observar o comportamento do Hubble para visualizar fluxos de rede e confirmar se as políticas estão sendo aplicadas conforme o esperado.

---

## 6. Como esse protótipo se conecta ao projeto

Este cenário inicial não representa a solução final da pesquisa. Ele serve como infraestrutura mínima para explorar os conceitos que serão expandidos no projeto principal:

- observabilidade de tráfego em tempo real
- classificação por origem e destino de comunicação
- monitoramento de serviços e agentes em Kubernetes
- uso de eBPF para coleta de métricas e inspeção de rede

A evolução natural do laboratório é migrar desse cenário simples para um ambiente que consiga mapear e mensurar fluxos gerados por agentes de IA, com foco em performance, segurança e análise de redes em produção.

---

## 7. Observação

Este protótipo é uma etapa inicial e didática. O objetivo principal é validar a comunicação básica entre serviços e a política de isolamento de rede antes de avançar para cenários com maior complexidade e maior aderência à proposta de pesquisa.
