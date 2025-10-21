.PHONY: kind up down gatekeeper policies gator demo bad good clean

kind:
	kind create cluster --config infra/cluster/kind-config.yaml

up: kind
	./infra/cluster/install_gatekeeper.sh
	./scripts/apply_policies.sh

down:
	kind delete cluster

gatekeeper:
	./infra/cluster/install_gatekeeper.sh

policies:
	./scripts/apply_policies.sh

gator:
	gator verify ./tests/gator

demo:
	./scripts/test_violation_demo.sh

bad:
	kubectl apply -f manifests/bad/ || true

good:
	kubectl apply -f manifests/good/

clean:
	./scripts/cleanup.sh
