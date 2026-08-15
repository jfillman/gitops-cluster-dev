# gitops-cluster-dev

Declarative config for the `kind-dev` cluster (kept deliberately separate from
`kind-observe`, `platform-cicd`'s own live Tekton dev cluster — see
`idp/README.md`'s naming note) — the cluster-admin-owned half of the topology in
`idp/docs/gitops-strategy.md` §1/§3. Static, mostly-slow-changing config only; per-app
onboarding lives in the sibling `gitops-cluster-dev-tenants` repo, read by
`02-argocd-apps/`'s three `ApplicationSet`s.

## Layout

One top-level directory per logical group, one ArgoCD `Application` per group, all
owned by a single app-of-apps root (`root-app-of-apps.yaml`) — per §3 of the strategy
doc. Numeric prefixes are human ordering hints, not a dependency mechanism ArgoCD
enforces.

```
00-bootstrap/        namespaces (documented, mostly pre-existing), RBAC/NetworkPolicy baseline (not yet built)
01-argocd/            ArgoCD's own install — documented, not yet self-managed (deferred, see status)
02-argocd-apps/       tenant-onboarding ApplicationSets (per-app AppProject + real app deployment + xr-requests/ XR onboarding) — real, wired 2026-08-13/15
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
see below). Both `NodeJSApplication` and `ApplicationEnvironment` (`idp-service-catalog`,
built 2026-08-13/15) now feed these for real — first proven end-to-end 2026-08-15 with a
throwaway app (namespace/`ServiceAccount`/`NetworkPolicy` actually rendered, `rollout:
null` path, exactly as `idp-application`'s own fixtures predicted).

That first real (not throwaway-fixture) pass through this path confirmed the
`AppProject.sourceRepos` boundary really rejects (`InvalidSpecError` on a repo not in
scope, at the ArgoCD reconciler level — same mechanism already proven in
`platform-cicd`), found that an `AppProject` with no `clusterResourceWhitelist` blocks
`CreateNamespace=true` outright (fixed — `Namespace` is now explicitly whitelisted, see
`02-argocd-apps/tenant-appprojects/chart/templates/appproject.yaml`), and found that
ArgoCD has no git credentials for any of `jfillman`'s **private** repos at all — every
prior pass happened to use public ones. Fixed by registering a `repo-creds` Secret
(`argocd-repo-creds-jfillman`, url-prefix `https://github.com/jfillman`) reusing
`provider-github`'s own already-cluster-resident PAT, rather than minting a second
overlapping credential.

**Fixed and live-verified 2026-08-15** (was: still open, hit twice — 2026-08-13 against
a fabricated throwaway tenant, confirmed again 2026-08-15 against a real
`NodeJSApplication`/`ApplicationEnvironment`-driven teardown): deleting an `AppProject`
before its dependent per-app `Application`'s own `resources-finalizer.argocd.argoproj.io`
finishes permanently stuck that `Application` — its finalizer needs to look up the very
`AppProject` that's already gone (`"error getting app project ... not found"`, retried
forever). Hit because `tenant-appprojects` and `tenant-onboarding` prune independently,
on their own separate git-generator cycles, with no ordering between them. Both times
worked around by clearing the stuck `Application`'s finalizer by hand — the real fix
didn't end up needing a `sync-wave`-equivalent ordering constraint on ArgoCD's
generator-driven pruning (which `ApplicationSet` doesn't obviously expose) at all: it's
a `protection.crossplane.io` `Usage`, composed by `idp-service-catalog`'s
`ApplicationEnvironment` Composition, blocking `NodeJSApplication` deletion at the
Crossplane layer (a real, already-installed admission webhook) while any referencing
env still exists — enforced before `tenants/<app>/app.yaml` (and therefore the
`AppProject` built from it) can ever be removed while an env's `Application` still
depends on it. See `idp-service-catalog` `v0.3.2` and `idp/docs/
service-catalog-design.md` §0 for the full mechanism and live-verification detail.

**New this pass (2026-08-15, same session): a cluster registry, and a real second
cluster.** `00-bootstrap/cluster-registry/` — one labeled `ConfigMap` per cluster
(`type: dev|upper`, `cicdReady`/`crossplaneReady` flags), cluster-admin-authored,
manual attestation not an automated probe. This is what
`ApplicationEnvironment.spec.cluster` (now a real required field, no longer a
hardcoded `"kind-dev"` Composition constant) gates against via a real Crossplane
extra-resources lookup — the first actual use of that mechanism in this catalog.
`kind-prod` is now registered and `crossplaneReady: "true"` for real: a scoped
Crossplane install (`gitops-cluster-kind-prod` — core + `provider-kubernetes` +
`function-go-templating`/`function-auto-ready` + just the `SLO` XRD, deliberately
**not** `provider-github` or the Bootstrap-tier XRDs, which stay `kind-dev`-only
permanently) proven live end-to-end with a throwaway app: both the rejection path
(`crossplaneReady: "false"` → zero resources created) and the success path (real
commits, `kind-prod`'s own ArgoCD — its **pre-existing** instance, reused rather than
duplicated, see that repo's own README for why — picking up the new tenant
unprompted, a real namespace/`ServiceAccount`/`NetworkPolicy`). `kind-prod` also
needed its own `argocd-repo-creds-jfillman` Secret, same fix as above but per-cluster
— each ArgoCD instance needs its own credential registration, confirmed live rather
than assumed to carry over.

One real bug found and fixed along the way: the cluster-shared `tenants/<app>/
app.yaml` was designed to use `spec.deletionPolicy: Orphan` (so tearing down one env
never deletes a file a sibling env on the same cluster still needs) — but
`provider-upjet-github` v0.19.1's `RepositoryFile` CRD has no such field at all,
confirmed via a real `ReconcileError` (`.spec.deletionPolicy: field not declared in
schema`) plus `kubectl explain`. Fixed with `managementPolicies` excluding
`"Delete"` instead — same intent, correct field for the schema that's actually
installed. Worth remembering for any future provider/field assumption: check
`kubectl explain` against the real installed CRD version before trusting an older
field name still applies.

**New this pass (2026-08-15, same day): `02-argocd-apps/xr-requests/` — real GitOps
onboarding for Bootstrap-tier XRs, built and live-verified.** `idp/docs/
service-catalog-design.md` §0's `xr-requests/` mechanism: a git commit into
`gitops-cluster-dev-tenants/tenants/<app>/xr-requests/` now creates
`NodeJSApplication`/`ApplicationEnvironment` XRs for real, replacing every prior
`kubectl apply`-based live-verification pass. A dedicated `idp-onboarding`
`AppProject` (not `default`, not the per-app one — both are circular for a brand-new
app whose `app.yaml` doesn't exist yet) scopes it to just those two kinds, sourced only
from the tenants repo. Live-verified twice end-to-end with a throwaway app
(`xr-onboarding-verify`) across both `kind-dev` and `kind-prod`, including a real
`AppProject` boundary attack-test (a committed `Secret` rejected with `resource
:Secret is not permitted in project idp-onboarding`).

Two real bugs found live, one fixed:
- **Fixed**: a directory-type `Application` source pointed straight at `xr-requests/`
  errors manifest generation entirely (`app path does not exist`) once its last file is
  removed — git doesn't track empty directories, and that's exactly the moment a real
  deletion needs a clean diff to zero. Fixed by sourcing from the always-present
  `tenants/<app>` directory with `recurse: true` + `include: "xr-requests/*.yaml"`
  instead of pointing straight at the subfolder.
- **Still open, confirmed twice**: deleting an `ApplicationEnvironment` through this
  path deadlocks — the `Usage` it composes won't release its own finalizer until the
  `ApplicationEnvironment` is actually gone, but the `ApplicationEnvironment` (via k8s's
  `foregroundDeletion` finalizer) won't finish going away until that same `Usage` (an
  owned, `blockOwnerDeletion: true` dependent) is gone first. `PrunePropagationPolicy=
  background` was tried and did **not** fix it. Every prior `Usage`-fix
  live-verification used a plain `kubectl delete` instead of ArgoCD prune, so this
  never surfaced before. Recovery requires manually clearing the `Usage`'s own
  finalizer — see `02-argocd-apps/xr-requests/applicationset.yaml`'s own header for the
  exact command. Do not treat env deletion through `xr-requests/` as routine yet.

Also worth noting: the `AppProject`-deletion-ordering bug above did **not** recur
during this pass's teardown, on either cluster — because the orphaned `app.yaml`
correctly kept each `AppProject` alive until a deliberate, separate manual delete,
the two `ApplicationSet`s never got the chance to race. Not a fix for the underlying
bug on its own (see above for the real fix, also landed 2026-08-15), but a real data
point that the orphan design avoids triggering it in the one case this session
exercised even before the `Usage`-based fix existed.

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
