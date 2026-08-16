# tekton-operator

Installs Tekton Pipelines/Triggers/Chains/Dashboard/Pipelines-as-Code on `kind-dev` via
[tektoncd/operator](https://github.com/tektoncd/operator) (v0.81.0, vendored) instead of
the raw-manifest-per-component install `hack/bootstrap.sh` uses for `kind-observe`.
`kind-observe` is untouched - this is `kind-dev`-only, see `50-platform-cicd/README.md`.

## Why the operator, and why NOT a Helm chart

Real Helm charts exist for individual components
(`cdfoundation/tekton-helm-chart` for Pipelines,
`chainguard-dev/tekton-helm-charts` for Chains/Dashboard) - checked live, not assumed.
Only the Pipelines chart is actually current (1.6.0, matching what was running); the
Chains/Dashboard charts are badly stale (max appVersion v0.9.0/v0.24.1 against
v0.26.0/v0.70.0 actually running) - using them would be a real downgrade, not a
like-for-like migration. No chart exists anywhere for Triggers or Pipelines-as-Code.

`tektoncd/operator` is the Tekton project's own official install mechanism and covers
all 5 components in one place. Real tradeoff, accepted deliberately: it doesn't support
pinning individual component versions the way this platform's raw-manifest installs do
(`PAC_VERSION`/`TEKTON_DASHBOARD_VERSION` in `hack/bootstrap.sh`) - whatever versions ship
bundled with the operator release is what you get.

## What's real, not assumed - live-verified against a throwaway kind cluster, 2026-08-16

- **Everything lands in ONE namespace** (`spec.targetNamespace`, `tekton-pipelines`
  here), not each component's own conventional namespace. This is the single biggest
  structural difference from `kind-observe`'s layout and has a real ripple: anything that
  hardcoded `tekton-chains`/`pipelines-as-code` as a namespace name had to change - see
  `platform-cicd`'s own `tektonChainsNamespace` value
  (`charts/platform-cicd-control-plane`, `charts/platform-cicd-catalog`,
  `hack/values-kind-dev.yaml`), most importantly `verify-image-provenance.yaml`/
  `verify-sast-attestation.yaml`'s cosign `--certificate-identity-regexp` - a
  security-critical check (verifies a signature really came from the real Chains
  controller), not a cosmetic path.
- **`dashboard.readonly` defaults to `false`** (write-enabled) - this platform
  deliberately runs Dashboard read-only everywhere else (`hack/bootstrap.sh`'s own
  comment: a write-enabled dashboard is a standing bypass around the "no elevated
  identity anywhere" posture). Set explicitly in `tektonconfig.yaml`, confirmed live via
  the rendered Deployment's own `--read-only=true` arg - not trusted as inherited.
- **`profile: all` bundles Tekton Results** (an archival/results-API component this
  platform has never used) automatically. Disabled via `spec.result.disabled: true` -
  confirmed live it tears down cleanly, not just that the field exists.
- **Pipelines-as-Code IS covered on plain Kubernetes** via
  `spec.platforms.kubernetes.pipelinesAsCode.enable` - a real, documented field, separate
  from the OpenShift-only `TektonAddon`/`OpenShiftPipelinesAsCode` mechanism this session
  found first and initially (incorrectly) concluded was the only path. Confirmed live
  running v0.50.0 - past the known v0.49.0 arm64 SIGSEGV crash `hack/bootstrap.sh` pins
  `PAC_VERSION=v0.48.1` to avoid, healthy with zero restarts on the same arm64 node class.

## Status

Live-verified 2026-08-16 against a real throwaway kind cluster (created and torn down
same session, never touched `kind-dev`): operator installs cleanly, `TektonConfig`
reaches `Ready`, all expected component Deployments come up healthy in one namespace,
Dashboard confirmed read-only, Results confirmed absent, PAC confirmed enabled and
healthy. Not yet applied to `kind-dev` itself - see `50-platform-cicd/README.md`'s own
status for the end-to-end onboarding+signed-build verification this still needs before
`kind-dev`'s existing imperative Tekton install can be considered superseded.
