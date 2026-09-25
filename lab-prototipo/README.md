# Laboratório de protótipo inicial

Esta pasta reúne a parte do laboratório relacionada à criação da infraestrutura mínima em Kubernetes e à validação inicial de rede com Cilium.

## Objetivo

Subir um ambiente simples com três pods e aplicar uma política de rede para demonstrar o comportamento do Cilium e do Hubble.

---

## 1. Preparar o cluster

Antes de executar esta parte, certifique-se de que o cluster Kubernetes já está pronto e que o comando `kubectl` está funcionando:

```bash
kubectl get nodes
```

Se o comando retornar os nós do cluster, o ambiente está pronto para continuar.

---

## 2. Criar os Pods

Crie o arquivo `lab-app.yaml` com o conteúdo da pasta:

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

---

## 3. Criar os Services

Aplique os serviços:

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

O arquivo `policy.yaml` permite apenas que o pod `backend` tenha acesso ao pod `database`.

---

## 5. Arquivos desta pasta

- `lab-app.yaml`
- `lab-services.yaml`
- `policy.yaml`

---

## 6. Comandos úteis

```bash
kubectl get pods
kubectl get svc
kubectl get cnp
kubectl describe pod backend
kubectl describe pod database
```

---

## 7. Observação

Esta é uma etapa inicial de protótipo. O objetivo é validar a comunicação básica entre serviços e a política de isolamento de rede antes de evoluir para cenários mais complexos.
