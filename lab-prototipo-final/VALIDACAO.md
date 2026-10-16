# Validação executada em 14/10/2026

Para a explicação das decisões e do funcionamento, consulte [DOCUMENTACAO.md](DOCUMENTACAO.md). Para reproduzir os comandos, consulte [README.md](README.md).

Ambiente real neste host: Docker 29.1.4; cluster dedicado `agent-trap-lab`, node Kubernetes 1.34.0, Cilium/Hubble 1.20.2, CLI Hubble 1.20.2. Kubeconfig e binários locais em `.state/`, sem alterar configuração global.

## Resultados

- **10 testes passaram** em Python 3.12, com servidor HTTP real em loopback: quatro variantes, tokens, TTL, resposta incorreta, replay, persistência/reinício, concorrência com 24 callbacks e um primeiro retorno, headers hostis, exclusão de scrapes/probes, falha transitória SQLite, compatibilidade com evento incompleto e histograma inicial zerado.
- Cluster criado, Cilium/Envoy/Hubble, aplicação, Prometheus e Grafana executados com pods prontos.
- Smoke de cliente Docker **fora do Kubernetes**, pela rede `kind` e NodePort: PASS. Primeira execução: 11 eventos, uma exposição por variante, zero retornos no controle e um primeiro retorno nas outras três variantes.
- Reaplicação com build/load e restart preservou SQLite. Segundo smoke: 22 eventos e duas exposições por variante, sem perder a primeira execução.
- Header sintético `GPTBot/1.0`: smoke PASS; classificação `provider=openai`, apenas declaração. Total após três execuções: 33 eventos, nove primeiros retornos nas variantes com estímulo e zero no controle.
- Hubble observou eventos HTTP L7 e headers `User-Agent` dos clientes externos; captura com CLI 1.20.2 confirmou `GPTBot/1.0`. Evidência JSONL local em `.state/hubble-validation.jsonl` inclui dados do experimento e não é versionada.
- Prometheus: alvos `trap`, `cilium-agent` e `prometheus` com `health=up`.
- Grafana: dashboard provisionado com 16 painéis; todas as 17 consultas PromQL (um painel tem p50 e p95) executaram com sucesso via APIs e retornaram séries após os testes.
- `promtool check config` validou a configuração real; `kubectl apply --dry-run=server` validou todos os manifests e a CiliumNetworkPolicy contra a API real.
- Scripts Bash passaram em `bash -n`. `make tools` completou instalação local das quatro CLIs com checksums oficiais.

## Correções identificadas pela validação

O kind com CNI padrão desabilitado não deve esperar nodes Ready antes de instalar Cilium. Cilium Operator usa uma réplica neste cluster de um node. Prometheus/Grafana usam rollout Recreate para evitar instâncias compartilhando o mesmo volume; um rollout real revelou o lock do TSDB antes dessa correção. A reaplicação concluiu após o ajuste, preservando dados.

A revisão de callbacks encontrou erro transitório SQLite capaz de persistir evento incompleto e quebrar métricas; o fallback e seu teste de regressão corrigem isso. Histogramas de atraso iniciam em zero e o painel usa quantis acumulados para incluir experimentos esparsos.

## Limites da evidência

Nenhum LLM real foi executado; os clientes de smoke são scripts determinísticos. Nenhuma taxa de detecção de IA ou ilegitimidade foi medida. Não foram testados HTTPS, acesso público, containerlab, CDN, carga prolongada ou reinicialização completa do host. O provisionamento e as consultas de Grafana foram verificados por API, sem inspeção visual no navegador.

Atualização do estado do desafio e gravação do evento HTTP são transações separadas: uma falha de processo entre elas pode perder uma tentativa/evento HTTP, mas o primeiro retorno e seu atraso permanecem persistidos. A coleta de fluxos CLI deve ser iniciada explicitamente; não há garantia de captura contínua sem perdas. Detalhes em [README.md](README.md).
