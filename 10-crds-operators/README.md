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
