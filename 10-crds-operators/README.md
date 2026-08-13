# 10-crds-operators

Crossplane + Providers/Configurations, cert-manager, External Secrets Operator,
ingress — per `gitops-strategy.md` §3.

## Adopted, real, live-verified this pass

- `crossplane/` — the Crossplane controller itself (Helm), `provider-kubernetes`, and
  the Functions in use: the original four (`function-auto-ready`,
  `function-go-templating`, `function-patch-and-transform`, `function-rollout-watcher`)
  plus `function-go-templating-slo` (`function-slo-templates.yaml`) — a second
  `function-go-templating` registration with its own `DeploymentRuntimeConfig`/
  ConfigMap mount, dedicated to the `SLO` Composition
  (`idp-service-catalog/compositions/slo/`) so its templates don't share the
  ai-rollout `Application` Composition's own `/templates` mount.
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
