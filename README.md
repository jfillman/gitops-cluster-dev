# gitops-cluster-dev

Declarative config for the `kind-dev` cluster (kept deliberately separate from
`kind-observe`, `platform-cicd`'s own live Tekton dev cluster — see
`idp/README.md`'s naming note) — the cluster-admin-owned half of the topology in
`idp/docs/gitops-strategy.md` §1/§3. Static, mostly-slow-changing config only; per-app
onboarding lives in the sibling `gitops-cluster-dev-tenants` repo, read by
`02-argocd-apps/`'s two `ApplicationSet`s.

## Layout

One top-level directory per logical group, one ArgoCD `Application` per group, all
owned by a single app-of-apps root (`root-app-of-apps.yaml`) — per §3 of the strategy
doc. Numeric prefixes are human ordering hints, not a dependency mechanism ArgoCD
enforces.

```
00-bootstrap/        namespaces (documented, mostly pre-existing), RBAC/NetworkPolicy baseline (not yet built)
01-argocd/            ArgoCD's own install — documented, not yet self-managed (deferred, see status)
02-argocd-apps/       tenant-onboarding ApplicationSets (per-app AppProject + real app deployment) — real, wired 2026-08-13
10-crds-operators/    Crossplane + providers/functions, cert-manager, external-secrets, Argo Rollouts, ingress
20-service-catalog/   idp-service-catalog XRDs/Compositions, git-tag pinned — real, wired 2026-08-13
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
`20-service-catalog/` (`idp-service-catalog`'s XRDs/Compositions, git-tag pinned) is
real and wired as of 2026-08-13 — see that directory's own README.
`02-argocd-apps/`'s two `ApplicationSet`s (`tenant-appprojects`, `tenant-onboarding`) are
real and live-verified as of 2026-08-13, built inside the existing single `01-argocd`
instance rather than a real second `argocd-apps` instance (that split is still deferred,
see below) — they're not fed by a real XRD yet (`NodeJSApplication`/
`ApplicationEnvironment` aren't built), verified with a throwaway test tenant instead.
That verification pass confirmed the `AppProject.sourceRepos` boundary really rejects
(`InvalidSpecError` on a repo not in scope, at the ArgoCD reconciler level — same
mechanism already proven in `platform-cicd`), and surfaced a real bug worth knowing
before touching either `ApplicationSet` again: **deleting an `AppProject` before its
dependent per-app `Application`'s own `resources-finalizer.argocd.argoproj.io` finishes
permanently stuck that `Application`** — its finalizer needs to look up the very
`AppProject` that's already gone (`"error getting app project ... not found"`, retried
forever). Hit because `tenant-appprojects` and `tenant-onboarding` prune independently,
on their own separate git-generator cycles, with no ordering between them. Worked around
by clearing the stuck `Application`'s finalizer by hand for the throwaway test case —
not yet a designed fix (a real one likely needs a `sync-wave`-equivalent ordering
constraint on generator-driven pruning, which ApplicationSet doesn't obviously expose;
worth investigating before a real tenant's `Application` gets stuck the same way).

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
