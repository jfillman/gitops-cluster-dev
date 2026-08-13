# gitops-cluster-dev

Declarative config for the `kind-observe` dev cluster — the cluster-admin-owned half of
the topology in `idp/docs/gitops-strategy.md` §1/§3. Static, mostly-slow-changing
config only; per-app onboarding lives in the sibling `gitops-cluster-dev-tenants` repo,
referenced from `02-argocd-apps/` (not yet built — see status below).

## Layout

One top-level directory per logical group, one ArgoCD `Application` per group, all
owned by a single app-of-apps root (`root-app-of-apps.yaml`) — per §3 of the strategy
doc. Numeric prefixes are human ordering hints, not a dependency mechanism ArgoCD
enforces.

```
00-bootstrap/        namespaces (documented, mostly pre-existing), RBAC/NetworkPolicy baseline (not yet built)
01-argocd/            ArgoCD's own install — documented, not yet self-managed (deferred, see status)
10-crds-operators/    Crossplane + providers/functions, cert-manager, external-secrets, Argo Rollouts, ingress
20-service-catalog/   idp-service-catalog XRDs/Compositions (Phase 2 — not built yet)
30-policy/            cluster-wide guardrails (not built yet)
40-observability/     Prometheus/Grafana/Tempo/Loki/Thanos/MinIO/otel-collector/HolmesGPT (documented, not yet re-templated)
50-platform-cicd/     platform-cicd's own control plane + Tekton/PaC/sigstore stack (documented, not yet re-templated)
```

## Status (as of this repo's creation, 2026-08-12)

This is a capture-in-progress of a cluster that's been live and in active use for
weeks, not a fresh install — see each directory's own README for exactly what's real
(an ArgoCD-adopted `Application`, live-verified) vs. documented-only (accurately
describes what's running, but ArgoCD isn't managing it yet). Don't assume everything
listed here is already under GitOps management — check each group's README.

**Real, adopted, live-verified this pass**: `10-crds-operators/`'s Helm-based pieces
(Crossplane + its providers/functions, cert-manager, external-secrets).

**Documented only, adoption deferred (each has a stated reason, not an oversight)**:
`01-argocd` (ArgoCD managing its own install has real bootstrap-ordering risk, doing
this alongside the two-ArgoCD-instance split makes more sense — see
`idp/docs/gitops-strategy.md` §4's phase 4), Argo Rollouts + Contour ingress inside
`10-crds-operators/` (both raw-manifest installs pinned to a specific version, not yet
re-vendored), `40-observability/` and `50-platform-cicd/` (many releases, several with
substantial custom values — capturing all of them accurately is the next increment, not
rushed into this one).

## Design language

Shares `platform-cicd`'s conventions — see `idp/README.md`'s "Design language" section.
`platform.io/*` labels, no live cross-cluster API calls, GitOps commit as the only
mutation path once the app-of-apps root is live.
