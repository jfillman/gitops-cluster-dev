# 50-platform-cicd

`kind-dev`-only: `platform-cicd`'s own control plane, made declarative - Tekton
(via `tektoncd/operator`, see `tekton-operator/README.md`), the `platform-cicd-catalog`
and `platform-cicd-control-plane` Helm releases (CDEvents broker, DORA exporter,
detectors, Fulcio, ClusterSecretStore), all owned by `argocd-platform`'s root per
`gitops-strategy.md` §7.

## Which instance this manages - not kind-observe's

`platform-cicd` runs on two clusters. `kind-observe` is the original, real instance -
live tenants (`nodejs-demo-app`, `cicd-flow-test-app`), real production-shaped traffic,
installed imperatively via `hack/bootstrap.sh` and staying that way; migrating it to
GitOps is separate, deliberately out-of-scope future work. `kind-dev` is a second,
newer, lower-stakes instance (stood up 2026-08-15, no real tenants) - **this directory
manages that one.** An earlier version of this README (Phase 1, before `kind-dev`'s
instance existed) described `kind-observe`'s state as this directory's target - that was
wrong by the time `kind-dev`'s instance existed and is corrected as of this rewrite.

## Layout

- `tekton-operator/` - Pipelines/Triggers/Chains/Dashboard/Pipelines-as-Code, via the
  vendored `tektoncd/operator` release + a `TektonConfig` CR. Own README covers the real
  tradeoffs found live (single-namespace install, Dashboard's readonly default, Results
  bundled-but-unwanted, PAC support confirmed on plain Kubernetes).
- `platform-cicd-catalog/` - Helm chart Application, same source `hack/bootstrap.sh`
  already installs from, made declarative.
- `platform-cicd-control-plane/` - Helm chart Application, values from
  `platform-cicd`'s own `hack/values-kind-dev.yaml` (the same file
  `hack/generate-cluster-values.sh` produces and `hack/bootstrap.sh` auto-discovers - one
  canonical source, not duplicated here).

**Not vendored here, deliberately**: External Secrets Operator - already installed
cluster-wide by `gitops-cluster-dev/10-crds-operators/external-secrets/`, a real,
default install matching what `hack/bootstrap.sh`'s own step 2/6 would do (confirmed live
- same chart, same namespace, same defaults). No second install needed.

## The cluster-agnostic mechanism this replaces

Per `feedback_cluster_agnostic_idp` memory: `kind-dev`'s previous install used a
hand-typed `hack/values-kind-dev.yaml` (openssl run by hand, cert material copy-pasted).
That's now generated (`hack/generate-cluster-values.sh`), and the chart-level values it
used to hand-type (`tenantsRepoUrl`/`tenantOnboardingApplicationSetName`) now derive from
a single `clusterName` value by convention - see `platform-cicd`'s own
`charts/platform-cicd-control-plane/values.yaml` comments. This directory is what
consumes the result of that mechanism declaratively, rather than a human running
`hack/bootstrap.sh` by hand against `kind-dev`.

## A real, security-relevant ripple found along the way

The operator installs Tekton into ONE namespace (`tekton-pipelines`), not each
component's own conventional namespace (`tekton-chains`, `pipelines-as-code`) a
raw-manifest install uses. `platform-cicd`'s `verify-image-provenance.yaml`/
`verify-sast-attestation.yaml` catalog Tasks verify Chains' own signing identity by
namespace (`--certificate-identity-regexp`, security-critical) - a new
`tektonChainsNamespace` value (both `platform-cicd-catalog` and
`platform-cicd-control-plane` charts) parameterizes this, defaulting to `tekton-chains`
(zero change for `kind-observe`), overridden to `tekton-pipelines` for `kind-dev` in
`hack/values-kind-dev.yaml` and this directory's own `platform-cicd-catalog/application.yaml`.

## Status

**Live-verified end-to-end 2026-08-16, `cicdReady` flipped `true`.** Applied for real to
`kind-dev` (after first proving `tekton-operator/`'s design against a real throwaway kind
cluster - see its own README): a throwaway tenant (`kind-dev-verify`, real
`tenants/*/identity.yaml` commit to `platform-cicd-kind-dev-tenants`) onboarded cleanly
through the real `platform-cicd-tenant-onboarding` ApplicationSet, and a manually
triggered `build` PipelineRun completed all 14 tasks and produced a real Chains-signed
attestation - confirmed by decoding the actual certificate, not just the
`chains.tekton.dev/signed` annotation: issuer `CN=platform-cicd-kind-dev-fulcio-root`
(kind-dev's own independent Fulcio root, not kind-observe's), signing identity
`https://kubernetes.io/namespaces/tekton-pipelines/serviceaccounts/tekton-chains-controller`
- exactly the identity `tektonChainsNamespace: tekton-pipelines` was built to make the
security-relevant identity check above pass. Two real bugs found and fixed only by
actually running a build, not by any dry-run or template diff:

- **kaniko's baked-in CA bundle was 2+ years stale** (`v1.23.2-debug`, dated 2024-07-08) -
  bumped to `v1.24.0` (latest available). A real fix on its own merits, but NOT what
  caused this session's actual failure (confirmed by testing - the newer image hit the
  byte-identical error).
- **The actual cause**: Tekton's own entrypoint injects `SSL_CERT_DIR` pointed at
  standard Linux cert paths that don't exist in kaniko's non-standard image (confirmed
  live - `/etc/ssl/certs` doesn't exist in it at all). Fixed with an explicit
  `SSL_CERT_FILE` override on the `build-and-push` step pointing at kaniko's real,
  non-standard bundle location. See `platform-cicd`'s own
  `charts/platform-cicd-catalog/templates/tasks/build-image.yaml` for the full writeup -
  this affects every cluster running this chart, not just `kind-dev`.

All throwaway resources (tenant identity.yaml, Application, both namespaces, the
PipelineRun) torn down after. `kind-dev`'s previous imperative Tekton/platform-cicd
install is superseded by this directory going forward.
