.PHONY: up destroy observe grafana prometheus hubble hubble-ui node-ip test smoke external-client tools topology-up topology-test topology-down
export PATH := $(CURDIR)/.state/bin:$(PATH)

up:
	./scripts/up.sh

tools:
	./scripts/tools.sh

destroy:
	./scripts/destroy.sh --confirm

observe:
	./scripts/observe.sh

grafana:
	kubectl --kubeconfig .state/kubeconfig -n agent-trap-lab port-forward svc/grafana 13000:3000

prometheus:
	kubectl --kubeconfig .state/kubeconfig -n agent-trap-lab port-forward svc/prometheus 19090:9090

hubble:
	kubectl --kubeconfig .state/kubeconfig -n kube-system port-forward svc/hubble-relay 4245:80

hubble-ui:
	kubectl --kubeconfig .state/kubeconfig -n kube-system port-forward svc/hubble-ui 18081:80

node-ip:
	./scripts/node-ip.sh

test:
	python3 -m unittest discover -s tests -v

smoke:
	python3 tools/smoke.py

external-client:
	./scripts/external-client.sh

topology-up:
	./scripts/topology.sh up

topology-test:
	./scripts/topology.sh test

topology-down:
	./scripts/topology.sh down
