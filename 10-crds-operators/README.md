# 10-crds-operators

Crossplane + Providers/Configurations, cert-manager, External Secrets Operator,
ingress — per `gitops-strategy.md` §3.

## Adopted, real, live-verified this pass

- `crossplane/` — the Crossplane controller itself (Helm), `provider-kubernetes`, and
  the four Functions in use (`function-auto-ready`, `function-go-templating`,
  `function-patch-and-transform`, `function-rollout-watcher`) - every Composition in
  this catalog, including the SLO one, shares this single `function-go-templating`
  registration via `source: Inline` (templates embedded directly in each
  Composition). **Do not register a second `Function` object pointing at a package
  reference already installed here** - tried that for the SLO Composition
  (isolating its templates via a dedicated mount) and it corrupted Crossplane
  v2.3.4's package-manager dependency-lock graph for every other Function on the
  cluster, found live when `function-auto-ready` lost its runtime Deployment
  entirely. `crossplane/native-resources-rbac.yaml` also lives here - Crossplane's
  controller `ServiceAccount` needs an explicit grant per native resource kind any
  Composition composes directly (currently `argoproj.io` Rollout/AnalysisTemplate,
  `batch` Job, `monitoring.coreos.com` PrometheusRule, `sloth.slok.dev`
  PrometheusServiceLevel) - it has no built-in RBAC for these, only its own API
  types.
- `sloth/` — Sloth (sloth.dev), installed straight from its own git repo path (not
  published to a Helm chart repo). Watches `PrometheusServiceLevel` CRs and
  generates the multi-window-multi-burn-rate `PrometheusRule` for each - the SLO
  Composition generates the CR, not the rule directly. See the Application's own
  header comments for the `sloth.extraLabels` gotcha (stamps labels onto individual
  generated rules, not the `PrometheusRule` object itself - that's on the
  Composition to set instead).
- `cert-manager/` — Helm, `crds.enabled: true` only, no other customization.
- `external-secrets/` — Helm, fully default values.

Each renders identically to what was already running (same chart, same pinned version,
same extracted values) — adoption should be a no-op sync, not a recreation. Verify via
unchanged resource creation timestamps after the app-of-apps root goes live, same check
used in `platform_cicd_session_argocd_onboarding`.

## Vendored + built (2026-08-13, live-verified on `kind-dev`)

- **`argo-rollouts/`** — vendored `install.yaml` pinned to v1.9.1 (was previously
  installed from a `.../releases/latest/download/...` URL - not reproducible, not
  really GitOps-safe). `ServerSideApply=true` from the start, given the pattern's
  now been hit three separate times on this cluster's other CRD-heavy installs.
- **`contour/`** — vendored `install.yaml` pinned to v1.32.1, namespace
  `projectcontour`. This is the cluster's ingress controller - first time it's been
  named explicitly in any `idp` design doc (`gitops-strategy.md` referred to
  "ingress" generically without knowing which one this cluster already runs); also
  the real value `idp-application`'s `networkPolicy.ingressControllerNamespaceSelector`
  had only as an explicitly-flagged, unconfirmed `ingress-nginx` guess - fixed there
  once this was confirmed live.
- **`crossplane/providers.yaml`'s new `provider-github` entry + `provider-github-config.yaml`**
  (2026-08-13) — backs `NodeJSApplication` (`idp-service-catalog`, the first Bootstrap-tier XRD,
  `idp/docs/service-catalog-design.md` §1). Real package name confirmed live against
  the provider's own source, not guessed: `crossplane-contrib/provider-upjet-github`.
  Two real corrections found live-verifying `NodeJSApplication`, both detailed in
  `provider-github-config.yaml`'s own header and `service-catalog-design.md` §1: the
  namespaced managed-resource family (`repo.github.m.upbound.io`), not the Cluster-scoped
  one (Crossplane v2 rejects a namespaced XR composing a Cluster-scoped resource
  outright), and a PAT, not `platform-cicd`'s existing GitHub App (GitHub Apps can't
  create repos under `jfillman`'s personal account at all - the Secret itself is never
  committed here).

## Built 2026-08-17, `helm template`-verified only, not yet live-synced

- **`infisical/`** — Infisical Community Edition, self-hosted, `idp/docs/
  service-catalog-design.md` Item 8's platform-infrastructure half (the `SecretStore`
  XRD that provisions per-(app,cluster) isolation on top of this instance doesn't exist
  yet - separate future work in `idp-service-catalog`). Chart identity (`infisical-standalone`
  1.10.0, Cloudsmith-hosted) confirmed against the real published index, not the
  misleading local folder name upstream uses. See the Application's own header for two
  real findings from tracing the chart's actual templates: `ingress.enabled: false`
  alone does not skip the bundled ingress-nginx controller (separate `ingress.nginx.enabled`
  key), and the bundled Postgres/Redis passwords can't be routed through
  `existingSecret` without breaking the app container's own connection-string env var,
  which reads `.Values.postgresql.auth.password`/`.Values.redis.auth.password` directly.
  Requires a manually-created `infisical-secrets` Secret (`AUTH_SECRET`/`ENCRYPTION_KEY`/
  `SITE_URL`) before first sync - see the Application's header for the exact command.
  Needs a real ArgoCD sync + pod-health check on `kind-dev` before this note can say
  "live-verified."
