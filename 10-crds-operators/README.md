# 10-crds-operators

Crossplane + Providers/Configurations, cert-manager, External Secrets Operator,
ingress — per `gitops-strategy.md` §3.

## Adopted, real, live-verified this pass

- `crossplane/` — the Crossplane controller itself (Helm), `provider-kubernetes`, and
  the four Functions already in use (`function-auto-ready`, `function-go-templating`,
  `function-patch-and-transform`, `function-rollout-watcher`).
- `cert-manager/` — Helm, `crds.enabled: true` only, no other customization.
- `external-secrets/` — Helm, fully default values.

Each renders identically to what was already running (same chart, same pinned version,
same extracted values) — adoption should be a no-op sync, not a recreation. Verify via
unchanged resource creation timestamps after the app-of-apps root goes live, same check
used in `platform_cicd_session_argocd_onboarding`.

## Documented only this pass, not yet adopted

- **Argo Rollouts** (`quay.io/argoproj/argo-rollouts:v1.9.1`) — installed via
  `kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml`
  (`ai-rollout/install/02-argo-rollouts.sh`). Real gap worth naming: that URL always
  resolves to *latest*, not a pinned version — not reproducible, not really GitOps-safe
  as originally installed. Currently running v1.9.1; vendoring a pinned copy of that
  exact manifest into this repo is the fast-follow, not done this pass.
- **Contour** (`ghcr.io/projectcontour/contour:v1.32.1`) — same shape, raw-manifest
  install, not yet vendored/adopted. This is the cluster's ingress controller — first
  time it's been named explicitly in any `idp` design doc; `gitops-strategy.md` referred
  to "ingress" generically without knowing which one this cluster already runs.

Vendoring both is mechanical (fetch the pinned-version manifest, commit it, point an
ArgoCD `Application` at the local path) — deferred only for scope, not because it's
hard or risky the way `01-argocd`'s self-management deferral is.
