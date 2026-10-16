# Protótipo intermediário do laboratório Cilium

Esta pasta evolui o [protótipo inicial](../lab-prototipo-inicial) para o problema central da pesquisa: **metrificar, através do Cilium, quais requisições vêm de agentes de IA autodeclarados**.

Um agente de IA autodeclarado é aquele que se identifica no cabeçalho HTTP `User-Agent` com um token público, como `GPTBot`, `ClaudeBot` ou `PerplexityBot`. Neste laboratório, o Cilium inspeciona o tráfego HTTP em camada 7 e o Hubble registra o `User-Agent` de cada requisição, o que permite classificá-las e contabilizá-las.

---

## Arquitetura

```text
 gerador-trafego ──HTTP (User-Agent variado)──▶ frontend ── backend ── database
        │                                          ▲
        │                                    Envoy (L7) do Cilium
        │                                          │
        └──────────── Hubble registra método, URL, status e User-Agent
                                                   │
                                     metricas-agentes-ia.sh classifica
```

- `frontend`, `backend` e `database` formam uma aplicação real de três camadas:
  - `frontend`: nginx servindo uma página HTML que lista artigos, com proxy reverso de `/api/` para o `backend` (porta 80);
  - `backend`: API em Python que consulta o banco e registra o User-Agent de cada requisição na tabela `acessos` (porta 8080);
  - `database`: PostgreSQL com as tabelas `artigos` e `acessos` criadas na inicialização (porta 5432).
- O código de cada componente fica em ConfigMaps dentro de `lab-app.yaml`, então não é preciso construir imagens nem usar `kind load`.
- `gerador-trafego` simula clientes externos, enviando requisições ao `frontend` com User-Agents de agentes de IA e de navegadores comuns.
- A política `frontend-l7-visibility` declara regras HTTP no `frontend`. Isso faz o Cilium redirecionar o tráfego para o proxy Envoy, e o Hubble passa a enxergar o conteúdo HTTP das requisições.
- O script `metricas-agentes-ia.sh` lê os fluxos do Hubble e gera as métricas.

---

## Estrutura dos arquivos

- `lab-app.yaml`: Secret com as credenciais do banco, ConfigMaps com o código e os pods `frontend`, `backend` e `database`
- `lab-services.yaml`: Services para comunicação interna (`frontend:80`, `backend:8080`, `database:5432`)
- `lab-trafego.yaml`: ConfigMap com a lista de User-Agents e o pod `gerador-trafego`
- `policy.yaml`: política `backend-database-policy` (herdada do protótipo inicial) e política L7 `frontend-l7-visibility`
- `agentes-ia.txt`: tokens de User-Agent reconhecidos como agentes de IA (um por linha)
- `metricas-agentes-ia.sh`: script que classifica e contabiliza as requisições observadas pelo Hubble

---

## 1. Pré-requisitos

O ambiente de [setup-vm.md](../setup-vm.md) deve estar pronto: cluster kind, Cilium, Hubble, `kubectl` e Hubble CLI. Também é necessário o `jq`, já instalado no passo 2 do setup.

```bash
kubectl get nodes
cilium status
```

Se o protótipo inicial ainda estiver aplicado no cluster, remova-o antes para evitar conflito de nomes:

```bash
kubectl delete -f ../lab-prototipo-inicial/ --ignore-not-found
```

---

## 2. Subir a aplicação

```bash
kubectl apply -f lab-services.yaml
kubectl apply -f policy.yaml
kubectl apply -f lab-app.yaml
kubectl wait --for=condition=Ready pod/frontend pod/backend pod/database --timeout=180s
kubectl get pods -o wide
kubectl get cnp
```

Os Services são criados primeiro porque o nginx do `frontend` resolve o nome `backend` ao iniciar. O `backend` instala o driver do PostgreSQL (`psycopg`) ao subir, por isso pode levar alguns segundos a mais para ficar pronto. A política `frontend-l7-visibility` deve existir antes do tráfego começar, para que as requisições já passem pelo proxy L7.

Para ver a página no navegador da VM:

```bash
kubectl port-forward pod/frontend 8080:80
# abra http://localhost:8080
```

O `port-forward` entra direto no pod, sem passar pela política do Cilium, então esse acesso não aparece nas métricas do Hubble.

---

## 3. Gerar o tráfego

```bash
kubectl apply -f lab-trafego.yaml
kubectl logs -f gerador-trafego
```

Cada linha do log mostra o status HTTP, o caminho e o User-Agent usado:

```text
200 / Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)
200 /api/artigos Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)
200 /api/artigos/1 Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)
404 /docs Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)
```

Para alterar os User-Agents simulados, edite o ConfigMap em `lab-trafego.yaml` e aplique de novo. O gerador relê a lista a cada ciclo, então a mudança é aplicada sem recriar o pod (o Kubernetes pode levar cerca de um minuto para atualizar o arquivo montado):

```bash
kubectl apply -f lab-trafego.yaml
```

Também é possível enviar uma requisição manual com um User-Agent qualquer:

```bash
kubectl exec gerador-trafego -- curl -s -o /dev/null -w "%{http_code}\n" -A "MeuAgente/1.0 (compatible; GPTBot/1.2)" http://frontend/
```

Para conferir o que a própria aplicação registrou (útil para comparar com as métricas do Hubble):

```bash
kubectl exec gerador-trafego -- curl -s http://frontend/api/acessos
kubectl exec database -- psql -U lab -d lab -c "SELECT user_agent, count(*) FROM acessos GROUP BY 1 ORDER BY 2 DESC;"
```

---

## 4. Observar as requisições no Hubble

Em um terminal separado, abra o acesso ao Hubble Relay:

```bash
cilium hubble port-forward
```

Em outro terminal, acompanhe os fluxos HTTP que chegam ao `frontend`:

```bash
hubble observe --type l7 --protocol http --to-label app=frontend -f
```

Para ver o User-Agent de cada requisição:

```bash
hubble observe --type l7 --protocol http --to-label app=frontend --last 20 -o jsonpb \
  | jq -r 'select(.flow.l7.type == "REQUEST")
           | .flow.l7.http.headers[]? | select(.key | ascii_downcase == "user-agent") | .value'
```

---

## 5. Metrificar as requisições de agentes de IA

```bash
chmod +x metricas-agentes-ia.sh
./metricas-agentes-ia.sh          # últimos 5 minutos, destino app=frontend
./metricas-agentes-ia.sh 15m      # outra janela de tempo
./metricas-agentes-ia.sh 5m app=backend
```

Exemplo de saída:

```text
Requisições HTTP observadas: 420
  Agentes de IA autodeclarados: 270 (64.29%)
  Demais clientes:              150 (35.71%)

Requisições por agente de IA:
  GPTBot: 30
  ChatGPT-User: 30
  ...

Requisições de demais clientes (por User-Agent):
  30	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36
  30	curl/8.10.1
  ...
```

A classificação é feita comparando o User-Agent, sem diferenciar maiúsculas e minúsculas, com os tokens de `agentes-ia.txt`. Para reconhecer um novo agente, basta adicionar seu token ao arquivo.

---

## 6. Solução de problemas

- **O script mostra 0 requisições:** confirme que `cilium hubble port-forward` está ativo e que `kubectl get cnp` lista `frontend-l7-visibility`. Sem regra L7, o Hubble registra apenas fluxos L3/L4, sem cabeçalhos HTTP.
- **As requisições aparecem, mas sem User-Agent:** verifique se a redação de cabeçalhos do Hubble está ativa (`cilium config view | grep -i redact`). Se estiver, libere o cabeçalho `user-agent`:

  ```bash
  cilium upgrade --reuse-values \
    --set hubble.redact.enabled=true \
    --set hubble.redact.http.headers.allow="{user-agent}"
  ```

- **O gerador recebe erro de conexão:** a política L7 só permite `GET` vindo de `app=gerador-trafego`. Qualquer outro pod ou método é bloqueado no `frontend`, o que pode ser confirmado com `hubble observe --verdict DROPPED`.

---

## 7. Limitações e próximos passos

- A identificação depende de o agente **se autodeclarar**. Um agente que use um User-Agent de navegador comum não é detectado por este método, e qualquer cliente pode falsificar o cabeçalho.
- O buffer do Hubble é limitado (por padrão, alguns milhares de fluxos por nó). Para janelas longas, é preciso exportar os fluxos com o Hubble Exporter ou coletar periodicamente.
- Próximos passos possíveis: expor as contagens como métricas do Prometheus (por exemplo, a métrica `httpV2` do Hubble combinada com rótulos de workload), visualizar no Grafana e cruzar o User-Agent com sinais de rede, como frequência de requisições e IPs de origem, para detectar agentes não declarados.
