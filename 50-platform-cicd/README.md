# 50-platform-cicd

Dev-cluster-only: Tekton, Pipelines-as-Code, the CDEvents broker, and the rest of
`platform-cicd`'s own control plane — per `gitops-strategy.md` §7 ("`platform-cicd`'s
own control plane... becomes cluster config like everything else, GitOps-managed by
`argocd-platform` rather than the ad hoc `helm upgrade` steps `hack/bootstrap.sh` uses
today").

## Current state (documented, not yet re-templated or adopted)

Two Helm releases (`platform-cicd-catalog` in `platform-catalog`,
`platform-cicd-control-plane` in `platform-system`, both chart `0.1.0`/app `1.0.0`,
sourced from `platform-cicd`'s own repo, not a public chart registry) plus the raw-manifest
Tekton/Pipelines-as-Code/sigstore stack (`tekton-pipelines`, `tekton-pipelines-resolvers`,
`pipelines-as-code`, `tekton-chains`, `fulcio-system`, `rekor-system` namespaces) that
`platform-cicd/hack/bootstrap.sh` already installs today.

**Deliberately deferred, matching `01-argocd-platform`'s reasoning**: this is the namespace
actually running every live build/test/deploy/release pipeline for `nodejs-demo-app`
and `cicd-flow-test-app` right now. Moving it under ArgoCD management is exactly the
kind of change worth doing carefully, live-verified per component, not as a bulk capture
alongside everything else in this first pass.
