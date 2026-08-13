# 01-argocd

ArgoCD's own install + self-management — per `gitops-strategy.md` §4, "let ArgoCD
manage ArgoCD."

## Current state (documented, not yet self-managed)

`install.yaml` in this directory is the vendored, pinned upstream manifest
(`https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.5/manifests/install.yaml`,
`quay.io/argoproj/argocd:v3.4.5`) — not an ArgoCD `Application` object, deliberately
(see "why not an Application" below). This is now a real, reproducible artifact,
confirmed live on `kind-dev` (2026-08-13): a from-scratch bootstrap, not just an
adoption of already-running state, the first time this exact procedure has been
proven end-to-end.

**Bootstrap steps, in order** (the one manual sequence before everything else becomes
a normal PR — same framing as `root-app-of-apps.yaml`'s own header comment):

```
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f 01-argocd/install.yaml
kubectl apply -f root-app-of-apps.yaml
```

**`--server-side`, not plain `apply` - a real bug hit live, not a style choice.**
Plain `kubectl apply` failed outright: `applicationsets.argoproj.io` (one of
ArgoCD's own CRDs) is too large for the `kubectl.kubernetes.io/last-applied-configuration`
annotation's 262144-byte limit (`metadata.annotations: Too long`). This is the exact
same failure mode later hit again, live, syncing `external-secrets`' CRDs through
ArgoCD itself - see that directory's `application.yaml` for the `ServerSideApply=true`
syncOption that's the equivalent fix for an ArgoCD-managed Application (this vendored
manifest isn't ArgoCD-managed, so the fix here is the `kubectl` flag directly, not a
`syncOptions` entry).

**Deliberately deferred, not an oversight**: getting ArgoCD to manage its own install
(vendoring the install manifest, wiring a self-referential root `Application`) has real
bootstrap-ordering risk — if it goes wrong, the instance that's currently the only thing
running `platform-cicd`'s live pipelines and this very cluster-config repo's own sync
goes with it. `gitops-strategy.md` §4's phase already groups this with the
two-ArgoCD-instance split (Phase 4 of the `idp` build) — doing both together, carefully,
once the rest of this repo's structure is proven out, rather than rushing self-management
in now. Version stays pinned as a real vendored manifest (`install.yaml`) in the
meantime, not just a version number in prose.
