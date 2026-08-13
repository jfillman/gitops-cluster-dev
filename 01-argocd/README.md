# 01-argocd

ArgoCD's own install + self-management — per `gitops-strategy.md` §4, "let ArgoCD
manage ArgoCD."

## Current state (documented, not yet self-managed)

One instance today, `quay.io/argoproj/argocd:v3.4.5`, installed via a plain
`kubectl apply` of ArgoCD's own install manifest (confirmed live — the
`argocd-cmd-params-cm` ConfigMap carries a `kubectl.kubernetes.io/last-applied-configuration`
annotation, not a Helm release; ArgoCD doesn't appear in `helm list -A`). This single
instance currently does the job both `argocd-platform` and `argocd-apps` will
eventually split into (§2 of `gitops-strategy.md`) — it already runs
`platform-cicd`'s `tenant-onboarding` and `nodejs-demo-app-pr-envs` ApplicationSets
alongside whatever else lands here.

**Deliberately deferred, not an oversight**: getting ArgoCD to manage its own install
(vendoring the install manifest, wiring a self-referential root `Application`) has real
bootstrap-ordering risk — if it goes wrong, the instance that's currently the only thing
running `platform-cicd`'s live pipelines and this very cluster-config repo's own sync
goes with it. `gitops-strategy.md` §4's phase already groups this with the
two-ArgoCD-instance split (Phase 4 of the `idp` build) — doing both together, carefully,
once the rest of this repo's structure is proven out, rather than rushing self-management
in now. Version stays pinned/documented here in the meantime.
