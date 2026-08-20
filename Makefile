# vc-sampleapp GitOps — chart tasks
#
# ENV selects the overlay directory (local | stage). Default: local.
#   make bootstrap                 # cluster prerequisites (once per cluster)
#   make images REGISTRY=...        # build + push app images
#   make secrets-apply ENV=local    # provision secrets (needs master key)
#   make deploy ENV=local           # install everything
#
# Secrets use a local symmetric master key (openssl AES-256); no SOPS.

ENV         ?= local
NS          ?= vc-sampleapp
APP_SVCS    := rscounter goapi js          # app charts: depend on `common`, use _shared.yaml
SECRET_DIR  := envs/$(ENV)/secrets
SHARED      := envs/$(ENV)/_shared.yaml
REG_NS      ?= registry
VERSION     := $(shell cat VERSION)

.DEFAULT_GOAL := help

# ---- cluster prerequisites -----------------------------------------------

.PHONY: bootstrap storage
storage: ## Install the default StorageClass (local-path) — needed by registry and app
	kubectl apply -k bootstrap/storage

bootstrap: ## Apply app namespace + storage from bootstrap/ (declarative)
	kubectl apply -k bootstrap/

# ---- local Docker registry (lightweight OCI, registry:2) ------------------

.PHONY: registry registry-clean registry-reset node-trust-registry registry-catalog
registry: storage ## Install the local Docker registry + web UI
	kubectl apply -k platform/registry
	kubectl -n $(REG_NS) rollout status deploy/registry    --timeout=180s
	kubectl -n $(REG_NS) rollout status deploy/registry-ui --timeout=180s
	@echo "registry API -> 127.0.0.1:30082  (push/pull docker-local/<img>:<tag>)"
	@echo "registry UI  -> http://127.0.0.1:30083   (use 127.0.0.1, NOT localhost)"

node-trust-registry: ## Configure the node's containerd to pull 127.0.0.1:30082 over HTTP (once per node)
	scripts/containerd-insecure.sh

registry-catalog: ## Show repositories currently in the local registry
	@curl -s http://127.0.0.1:30082/v2/_catalog | sed 's/^/  /' || echo "  registry not reachable on 127.0.0.1:30082"

registry-clean: ## Delete the local registry namespace (force-clears pods first)
	-kubectl -n $(REG_NS) delete pods --all --force --grace-period=0 2>/dev/null
	-kubectl delete namespace $(REG_NS) --wait=true

# THE global command for the registry: clean slate -> install -> wait until ready.
registry-reset: ## One command: wipe + reinstall the local registry
	$(MAKE) registry-clean
	$(MAKE) registry

# ---- images --------------------------------------------------------------

.PHONY: images
images: ## Build + push app images to the registry (set REGISTRY, APP_REPO)
	scripts/build-push.sh

# ---- validation ----------------------------------------------------------

.PHONY: deps lint template
deps: ## Pull the common library chart into each app chart
	@for c in $(APP_SVCS); do helm dependency build charts/$$c; done

lint: deps ## helm lint every chart
	helm lint charts/postgres -f envs/$(ENV)/postgres.yaml
	@for c in $(APP_SVCS); do helm lint charts/$$c -f $(SHARED) -f envs/$(ENV)/$$c.yaml; done

template: deps ## Render all manifests for ENV to stdout
	@echo "# ===== postgres ====="; helm template postgres charts/postgres -n $(NS) -f envs/$(ENV)/postgres.yaml
	@for c in $(APP_SVCS); do \
		echo "# ===== $$c ====="; \
		helm template $$c charts/$$c -n $(NS) -f $(SHARED) -f envs/$(ENV)/$$c.yaml; \
	done

# ---- secrets (master key) ------------------------------------------------

.PHONY: secrets-keygen secrets-encrypt secrets-apply
secrets-keygen: ## Generate the local master key (once)
	scripts/secrets-keygen.sh

secrets-encrypt: ## Encrypt every $(SECRET_DIR)/*.secret.yaml -> .enc
	@for f in $(SECRET_DIR)/*.secret.yaml; do \
		[ -e "$$f" ] || continue; scripts/secrets-encrypt.sh "$$f"; \
	done

secrets-apply: ## Decrypt + apply every $(SECRET_DIR)/*.secret.yaml.enc
	@for f in $(SECRET_DIR)/*.secret.yaml.enc; do \
		[ -e "$$f" ] || { echo "no encrypted secrets in $(SECRET_DIR) — run 'make secrets-encrypt ENV=$(ENV)'"; exit 1; }; \
		scripts/secrets-apply.sh "$$f"; \
	done

# ---- deploy --------------------------------------------------------------

.PHONY: deploy down
deploy: deps bootstrap secrets-apply ## Prereqs + secrets, then install all charts in order
	helm upgrade --install postgres charts/postgres -n $(NS) -f envs/$(ENV)/postgres.yaml
	@for c in $(APP_SVCS); do \
		helm upgrade --install $$c charts/$$c -n $(NS) \
			-f $(SHARED) -f envs/$(ENV)/$$c.yaml --set image.tag=$(VERSION); \
	done
	@echo "deployed ENV=$(ENV) version=$(VERSION). Port-forward: kubectl -n $(NS) port-forward svc/js 3000:3000"

down: ## Uninstall all releases (keeps PVC + secrets)
	-@for c in postgres $(APP_SVCS); do helm uninstall $$c -n $(NS); done

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
