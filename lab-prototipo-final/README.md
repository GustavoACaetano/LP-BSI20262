# Laboratório de agentes externos

Documentos: [explicação técnica — o que, por que e como](DOCUMENTACAO.md), [evidências de validação](VALIDACAO.md). Este README é o guia de execução e diagnóstico.

Para a instalação de 16/10/2026 na VM, com topologia containerlab e acessos persistentes pelo IP privado, consulte [operação da VM 192.168.122.131](VM-192.168.122.131.md). Os comandos de parada dessa versão incluem clientes e serviços de acesso, além do cluster.

Experimento local de identificação declarada por `User-Agent` e de resposta a estímulos HTTP. Um cliente externo ao Kubernetes acessa uma aplicação pelo NodePort; Cilium/Envoy observa HTTP L7, Hubble expõe fluxos, a aplicação persiste eventos em SQLite e Prometheus/Grafana apresentam métricas.

**Retornar a um desafio não confirma IA nem ilegitimidade.** O catálogo registra apenas a declaração do header. Não há autenticação por IP oficial, bloqueio automático, chamadas a provedores de IA ou acesso público à internet. O cliente de demonstração é um script determinístico, nunca evidência de comportamento de um LLM.

## Arquitetura e limites

```text
Cliente Docker fora do Kubernetes (rede Docker kind)
  -> agent-trap-lab-control-plane:30080
  -> Cilium/Envoy (política HTTP permite qualquer requisição na porta observada)
  -> trap:8080 -> SQLite persistente

Prometheus -> trap /metrics e Hubble metrics :9965
Grafana -> Prometheus
Hubble CLI -> Relay -> captura JSONL local
```

O novo cluster chama-se `agent-trap-lab`; kubeconfig, cache Helm, dados e credenciais ficam em `.state/`, ignorado pelo Git. O protótipo anterior e o kubeconfig global não são alterados. Não é necessário containerlab para este cenário: o container cliente externo já usa a rede Docker `kind`, à qual clientes da topologia containerlab também podem ser conectados conforme sua configuração.

HTTP sem TLS é intencional neste laboratório fechado para verificar headers L7. HTTPS com criptografia fim a fim não expõe `User-Agent` ao Hubble; uma evolução deverá terminar TLS no gateway e observar o trecho HTTP apropriado. O IP registrado é o peer do socket, sem confiar em `X-Forwarded-For`; NAT/Envoy pode fazer esse valor diferir do IP original. O contexto de rede do Hubble é evidência complementar, sem correlação por requisição automaticamente implementada.

## Pré-requisitos

Linux, Docker em execução e acessível ao usuário, `kind`, `kubectl`, Helm 3.13+, `openssl`, `rg`, Python 3.12+ e `make`. Hubble CLI é necessário apenas para captura de fluxos. Downloads de imagens/charts precisam de internet. Reserve aproximadamente 4 CPUs e 8 GB de memória para o cluster e observabilidade.

Configuração fixada: kind node Kubernetes `v1.34.0`, Cilium `1.20.2`, Prometheus `v3.5.0`, Grafana `12.1.0`, aplicação `python:3.12-slim`. A imagem Python tem tag de série, sem digest imutável. `make tools` instala kind 0.33.0, kubectl 1.34.0, Helm 3.19.0 e Hubble 1.20.2 apenas em `.state/bin`, verificando checksums oficiais; requer curl, tar, awk e sha256sum. O laboratório não instala ferramentas globalmente. Alternativamente, consulte [setup-vm.md](../setup-vm.md).

## Executar

```bash
cd /home/gabriel/LP-BSI20262/lab-agentes-externos
make test
make tools   # Opcional se as CLIs já estão disponíveis; requer internet
make up
```

`make up` cria um cluster dedicado, configura Cilium e carrega a imagem local. Pode ser repetido para reaplicar manifests; reinicia os deployments para carregar a imagem e configurações atuais, preservando dados. Um cluster de mesmo nome sem o kubeconfig local esperado não é adotado. Os comandos `kubectl` abaixo exigem a CLI no PATH; se usou `make tools`, execute `export PATH="$PWD/.state/bin:$PATH"` neste terminal.

Abra `http://127.0.0.1:18080/`. O acesso host não substitui o teste externo abaixo, porque a observabilidade do caminho deve ser verificada separadamente.

Em terminais separados:

```bash
make grafana       # http://127.0.0.1:13000/d/agent-trap-lab
make prometheus    # http://127.0.0.1:19090/targets
make hubble-ui     # http://127.0.0.1:18081
make observe       # fluxos JSONL em .state/hubble.jsonl; Ctrl-C encerra
```

Grafana permite visualização anônima no laboratório; usuário admin tem senha aleatória em `.state/grafana-admin-password`. Não exponha interfaces administrativas nem APIs de eventos publicamente: elas incluem tokens e endereços do experimento. As portas de host e os port-forwards usam loopback.

Teste primeiro com um cliente fora do cluster:

```bash
make external-client
# Demonstra somente falsificação da declaração, não um acesso real da OpenAI:
./scripts/external-client.sh --user-agent 'GPTBot/1.0'
```

O script visita todas as variantes, retorna aos desafios, repete callbacks e envia uma resposta incorreta ao desafio de transformação. A saída deve indicar `PASS`. Espere pelo menos dois intervalos de scrape (30 segundos) para visualizar taxas no Grafana.

Para um agente controlado real, configure uma ferramenta HTTP/navegação no mesmo container/rede e forneça o endereço impresso por `make node-ip`, porta `30080`. Peça a tarefa de leitura da página experimental; não instrua o agente diretamente a cumprir o callback, pois isso alteraria o teste. Registre separadamente modelo, versão, tarefa, ferramentas, permissões e data. Nenhum agente real é executado por este laboratório.

## Variantes

| Rota | Estímulo | Retorno válido |
|---|---|---|
| `/experiment/control` | Página sem estímulo; token interno não exposto | Nenhum callback é aceito |
| `/experiment/link` | Link HTML explícito | GET `/probe/<token>` |
| `/experiment/instruction` | Instrução textual sem hyperlink | GET `/probe/<token>` |
| `/experiment/transform` | Inverter uma sequência de caracteres e construir o caminho | GET `/probe/<token>/reverse/<resposta>` |

Tokens aleatórios e individuais expiram em 900 segundos; todas as respostas usam `Cache-Control: no-store`. Apenas o primeiro retorno válido conta como desafio retornado e gera uma amostra de atraso. Repetições são registradas separadamente. Token desconhecido/caminho inválido retorna 404, expirado retorna 410, resposta ou tipo incorreto retorna 422. Callback não executa ações adicionais.

As instruções usam somente dados gerados pelo próprio experimento e caminhos no mesmo serviço. Seguir o estímulo pode demonstrar processamento de conteúdo, mas scripts, crawlers e humanos também podem responder. Ignorá-lo não exclui IA. Mantenha os resultados de exposição provocada separados do comportamento natural.

## Eventos e métricas

`/api/summary` apresenta exposições e retornos por variante/provedor declarado. `/api/events?limit=100&after=0` retorna eventos em ordem crescente; continue usando o último `sequence` como cursor. `/api/export` usa a mesma paginação, com resposta JSON para download (não exporta todo o banco automaticamente). Os eventos contêm timestamp Unix UTC, IP do peer, UA limitado a 512 caracteres, status, duração, bytes, variante e resultado. Credenciais, cookies, corpo e query strings não são registrados. Stdout contém JSON dos mesmos eventos.

| Métrica | Significado |
|---|---|
| `lab_experiment_exposures_total` | Páginas experimentais emitidas por variante/provedor declarado |
| `lab_challenges_returned_total` | Desafios com ao menos um retorno válido |
| `lab_callback_attempts_total` | Tentativas por variante, resultado e declaração do callback |
| `lab_callback_delay_seconds` | Histograma de tempo até primeiro retorno válido |
| `lab_http_requests_total` | Requisições experimentais e erros por rota normalizada/método/status |
| `lab_http_request_duration_seconds` | Histograma de duração observada no servidor |
| `lab_http_response_bytes_total` | Bytes produzidos por rota normalizada |
| `lab_user_agent_requests_total` | Classificação declarada por provedor/categoria |
| `lab_db_events`, `lab_db_ready`, `lab_service_up` | Eventos e disponibilidade; acompanhe também `up` do Prometheus |
| `hubble_*` | Fluxos, HTTP L7, latência, DNS, TCP e descartes de rede |

O painel provisionado inclui exposições, retornos, fração de retorno, outcomes, atraso p50/p95 acumulado, HTTP, bytes, declaração, SQLite e visão Hubble. Os quantis acumulados permitem visualizar testes esparsos e não são limitados ao intervalo selecionado. Tokens, IPs, UAs livres e URLs completas não são labels Prometheus. Probes, scrapes e leitura das APIs são excluídos dos contadores experimentais; Hubble pode observar esse tráfego e não deve ser somado à contagem da aplicação.

A fração de retorno é acumulada e inclui tokens recentes ainda em aberto; não representa sensibilidade, especificidade ou acurácia de um detector. Para avaliação científica, utilize eventos por coorte, aguarde TTL e inclua crawlers, humanos e scripts como controles negativos. O scrape faz agregação do SQLite, adequado ao laboratório pequeno; não existe retenção automática e o custo cresce com os eventos. A capacidade indicada nos PVs locais não constitui quota real de disco. Monitore espaço antes de experimentos longos.

## Verificação e diagnóstico

```bash
make test
make smoke
python3 tools/check_observability.py  # Com make grafana/prometheus ativos
kubectl --kubeconfig .state/kubeconfig -n agent-trap-lab get pods,pvc
kubectl --kubeconfig .state/kubeconfig -n kube-system get pods
kubectl --kubeconfig .state/kubeconfig -n agent-trap-lab logs deploy/trap
```

No Prometheus, confirme `up{job="trap"} == 1` e `up{job="cilium-agent"} == 1`. Sem séries Cilium, verifique descoberta de pods, porta 9965 e configuração Hubble. Sem fluxos HTTP, confirme a CiliumNetworkPolicy e gere tráfego pelo cliente externo; `kubectl port-forward` direto à aplicação pode não atravessar o mesmo caminho de rede.

Hubble CLI é captura complementar iniciada por `make observe`, não um coletor sempre ativo ou uma garantia de armazenamento sem perdas. Erros aparecem no terminal; mensagens `lost_events` e interrupções devem ser consideradas na qualidade da coleta. `.state/hubble.jsonl` não possui rotação automática. A coleta de métricas Hubble pelo Prometheus independe desse comando.

## Persistência e remoção

SQLite, TSDB e Grafana usam diretórios exclusivos `.state/node-data/`, montados no node kind e em PVs locais. O servidor SQLite usa uma réplica com rollout `Recreate`. Reiniciar pods preserva dados; remover o cluster também preserva esses diretórios.

```bash
./scripts/destroy.sh --confirm
```

Esse comando remove apenas o cluster dedicado; não apaga dados e não executa `docker compose down -v` ou limpeza global. Para arquivar dados, pare a aplicação antes de copiar todo o diretório SQLite, incluindo WAL/SHM, ou use a API de backup SQLite. Guarde kubeconfig, senha, eventos e captures como dados locais do laboratório.

## Referências

- [Cilium em kind](https://docs.cilium.io/en/stable/installation/kind/)
- [Visibilidade L7 e redação](https://docs.cilium.io/en/stable/observability/visibility/)
- [Políticas L7](https://docs.cilium.io/en/stable/security/policy/layer7/)
- [Métricas Hubble](https://docs.cilium.io/en/stable/observability/metrics/)
- [Bots OpenAI](https://developers.openai.com/api/docs/bots), [Anthropic](https://support.claude.com/en/articles/8896518-does-anthropic-crawl-data-from-the-web-and-how-can-site-owners-block-the-crawler), [Perplexity](https://docs.perplexity.ai/docs/resources/perplexity-crawlers)
