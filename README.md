# vc-sampleapp-k8s-helm-argocd

GitOps (CD) repo that deploys the **vc-sampleapp** stack
(`js → goapi → rscounter → postgres`) to a local Kubernetes cluster with Helm — a
`common` Helm library chart, thin per-service charts, per-env values, a local
container registry, cluster bootstrap, and master-key secret tooling. Everything
is declarative and driven by `make`.

> **This is a reusable GitOps/Helm template, not app-specific glue.** The
> `common` library chart, the bootstrap / registry / secret tooling, and the
> `make` workflow work for **any** set of containerized services —
> `vc-sampleapp` (js / goapi / rscounter / postgres) is just the worked example
> wired up here. To use it for your own services, see
> [Adapting to your own services](#adapting-to-your-own-services).

The application source (Dockerfiles, service code) lives in a **separate repo**:

- **App / services:** <https://github.com/pskshksh/vc-sampleapp-go-rust-react>
- **This repo (deploy):** <https://github.com/pskshksh/vc-sampleapp-k8s-helm-argocd>

---

## Quick start (TL;DR)

```sh
# from an empty parent directory, clone BOTH repos side by side
git clone git@github.com:pskshksh/vc-sampleapp-go-rust-react.git
git clone git@github.com:pskshksh/vc-sampleapp-k8s-helm-argocd.git
cd vc-sampleapp-k8s-helm-argocd

limactl start --name=k8s template://k8s                       # local cluster
export KUBECONFIG="$HOME/.lima/k8s/copied-from-guest/kubeconfig.yaml"

make registry              # local Docker registry + UI
make node-trust-registry   # let the node pull from it over HTTP (once)
make images                # build the 3 app images (from the app repo) and push
make secrets-keygen        # local master key
cp envs/local/secrets/db.secret.example.yaml envs/local/secrets/db.secret.yaml
make secrets-encrypt ENV=local
make deploy ENV=local      # bootstrap + secret + install all charts

kubectl -n vc-sampleapp port-forward svc/js 3000:3000         # http://localhost:3000
```

---

## 1. Prerequisites

You need a local Kubernetes cluster and the CLIs below. On macOS (Homebrew):

```sh
brew install lima kubernetes-cli helm podman

# podman runs in its own VM — start it (used to build the images)
podman machine init      # first time only
podman machine start
```

| Tool | Why |
| --- | --- |
| `lima` (`limactl`) | runs the local Kubernetes VM |
| `kubectl` | talks to the cluster (has built-in `kustomize` via `-k`) |
| `helm` | renders/installs the charts |
| `podman` | builds the app container images |
| `openssl` | encrypts secrets (ships with macOS) |
| `kubeconform` *(optional)* | validates rendered manifests |

## 2. Get the code

Clone **both** repos into the same parent directory (the build step expects the
app repo at `../vc-sampleapp-go-rust-react` by default):

```sh
git clone git@github.com:pskshksh/vc-sampleapp-go-rust-react.git
git clone git@github.com:pskshksh/vc-sampleapp-k8s-helm-argocd.git
cd vc-sampleapp-k8s-helm-argocd
```

```
parent/
├── vc-sampleapp-go-rust-react/     # app source (Dockerfiles, code)
└── vc-sampleapp-k8s-helm-argocd/   # this repo — run make from here
```

## 3. Start the cluster

```sh
limactl start --name=k8s template://k8s
export KUBECONFIG="$HOME/.lima/k8s/copied-from-guest/kubeconfig.yaml"
kubectl get nodes        # STATUS should be Ready
```

Keep `KUBECONFIG` exported in every shell you run `make`/`kubectl` from.

## 4. Local Docker registry

A lightweight in-cluster registry (`registry:2`) on NodePort **30082** with a web
UI on **30083**. Images are pushed here and pulled for deployment.

```sh
make registry              # install registry + UI  (make registry-reset wipes + reinstalls)
make node-trust-registry   # once per node: containerd trusts 127.0.0.1:30082 over HTTP
```

- Registry API: `http://127.0.0.1:30082/v2/_catalog`  (or `make registry-catalog`)
- Registry UI:  **http://127.0.0.1:30083**  — use `127.0.0.1`, **not** `localhost`
  (`localhost` resolves to IPv6, which the Lima port-forward doesn't cover).

## 5. Build & push the app images

`make images` builds each service from the app repo with podman, streams it into
the Lima VM, and pushes it to the registry (this indirection is needed because on
macOS podman runs in its own VM and can't reach the registry directly — it's all
inside `scripts/build-push.sh`).

```sh
make images                            # tag = ./VERSION, APP_REPO=../vc-sampleapp-go-rust-react
# override if the app repo is elsewhere:
make images APP_REPO=/path/to/vc-sampleapp-go-rust-react
```

> First build pulls the golang/rust/node base images, so it can take a while on a
> slow link; the push itself is local and fast. Verify with `make registry-catalog`.

## 6. Secrets (master key)

The one real secret is the DB credential. Charts only **reference** the Secret
`vc-sampleapp-db`; its plaintext manifest is encrypted with a local symmetric
master key (openssl AES-256). Only the `*.secret.yaml.enc` ciphertext is
committed; `secrets/master.key` and `*.secret.yaml` are gitignored.

```sh
make secrets-keygen                     # once — creates secrets/master.key (keep safe, never commit)
cp envs/local/secrets/db.secret.example.yaml envs/local/secrets/db.secret.yaml
# local dev creds are fine as-is; then:
make secrets-encrypt ENV=local          # -> db.secret.yaml.enc
```

## 7. Deploy

```sh
make deploy ENV=local
kubectl -n vc-sampleapp get pods
kubectl -n vc-sampleapp port-forward svc/js 3000:3000   # http://localhost:3000
```

`make deploy` runs, in order: `helm dependency build` → `kubectl apply -k bootstrap/`
→ decrypt + apply the secret → `helm upgrade --install` postgres, then the 3 app
charts (each with `_shared.yaml` + its overlay, image tag from `VERSION`).

## Reset / teardown

```sh
make down                  # uninstall the app releases (keeps PVCs + secret)
make registry-reset        # wipe + reinstall the registry
limactl stop k8s           # stop the cluster VM
limactl delete k8s         # destroy it entirely
```

## Validate before deploying

```sh
make lint ENV=local
make template ENV=local | kubeconform -strict -summary   # if kubeconform installed
make help                                                # list every target
```

---

## Repo layout

```
bootstrap/            cluster prerequisites (kubectl apply -k)
  namespace.yaml        vc-sampleapp namespace, restricted Pod Security
  storage/              vendored local-path-provisioner (pinned) + default StorageClass
platform/registry/    local Docker registry (registry:2) + web UI (joxit)
charts/
  common/             library chart — all service templates live here once
  js|goapi|rscounter/ thin charts that consume common
  postgres/           standalone StatefulSet chart
envs/
  local/  stage/
    _shared.yaml       image registry + pull policy shared by the 3 app charts
    <svc>.yaml         per-service deltas
    secrets/*.enc      master-key-encrypted Secret manifests (DB credential)
scripts/              secrets (master key) · build-push · containerd trust
VERSION               image version tag (semver)
Makefile              storage · registry · images · secrets · deploy
```

## Adapting to your own services

Nothing here is specific to vc-sampleapp except the four charts and their env
overlays. The `common` library chart, `bootstrap/`, `platform/registry/`, the
secret tooling, and the `Makefile` are reusable as-is. To wire up your own
services:

1. **Add a chart per service** under `charts/<svc>/` — copy an existing one:
   - `Chart.yaml` depends on `common` (`repository: file://../common`)
   - `values.yaml` sets `image.repository`, `config` (env → ConfigMap),
     `secretEnv` (env ← existing Secret), `probes`, `networkPolicy`, resources
   - `templates/main.yaml` is just `{{ include "common.* }}` lines (identical
     across services). Stateful services follow the standalone `postgres` chart.
2. **Register it** in the `Makefile` (`APP_SVCS`) and in `scripts/build-push.sh`
   (image name → build context in your app repo).
3. **Add env overlays** `envs/<env>/<svc>.yaml` for per-service deltas; the
   registry prefix + pull policy come from `envs/<env>/_shared.yaml`.
4. **Point at your app repo** — set `APP_REPO` (or the default `../<your-app-repo>`)
   so `make images` builds from your source.
5. **Declare secrets** as encrypted manifests in `envs/<env>/secrets/` and
   reference them by name via `secretEnv` — never inline them in values.

Swapping the whole application is: replace `charts/*` + `envs/*` + the
`build-push.sh` contexts, and keep `common/`, `bootstrap/`, `platform/registry/`,
and the secret/registry `make` targets unchanged.

## Stage

`make deploy ENV=stage` — images pinned by digest (`envs/stage/*.yaml`), HPA/PDB/
topology spread enabled, `js` exposed via Ingress. Intended for a real registry
(e.g. ghcr) + ArgoCD reconciling `charts/*` + `envs/<env>/*`.

## Notes

- **Use `127.0.0.1:30082`, not `localhost`** for the registry (IPv4 vs IPv6).
- **HPA needs `metrics-server`** in the cluster (autoscaling is off in local).
- **`js` image runs as root** — the chart sets `runAsNonRoot: true`; rebuild the
  image non-root, or set `runAsNonRoot: false` in `charts/js/values.yaml` as a
  temporary fallback if it crash-loops.
- The local registry is HTTP + anonymous, reachable only from the node loopback
  and the host (pods can't reach it). Add TLS + auth for anything beyond local.
```
