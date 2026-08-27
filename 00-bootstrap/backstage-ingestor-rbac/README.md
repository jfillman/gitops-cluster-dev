# backstage-ingestor-rbac

Read-only RBAC on this cluster (`kind-dev`) for the `kubernetes-ingestor` Backstage
plugin running on `kind-man` (`idp/docs/backstage-design.md`, "Catalog ingestion" -
Phase 2). Backstage doesn't run on this cluster, so unlike `kind-man`'s own
`backstage-ingestor` ServiceAccount (which uses its pod's kubelet-projected, auto-
rotating token), this one needs a real, long-lived token Secret that Backstage
authenticates with remotely.

`rbac.yaml` creates that token Secret (`backstage-ingestor-token`, type
`kubernetes.io/service-account-token`) automatically - Kubernetes mints the token
value into it once the Secret and ServiceAccount both exist. Nothing here ever prints
or transmits the token itself; that's a manual step, same "manual by design" posture as
every other credential's ultimate source in this platform (see
`gitops-cluster-kind-man/60-backstage/backstage/github-oauth-secret.yaml` for the same
pattern with a different credential).

## One-time manual step (do this yourself, not through an assistant)

1. Once this Application has synced, retrieve the real token value:
   ```
   kubectl --context kind-dev -n backstage-system get secret backstage-ingestor-token -o jsonpath='{.data.token}' | base64 --decode
   ```
2. Plant it into Infisical's `platform-cicd-kind-man` project (same project
   `backstage-github-oauth-client-id`/`-secret` already live in) under the key:
   ```
   backstage-kind-dev-sa-token
   ```
3. `gitops-cluster-kind-man/60-backstage/backstage/kind-dev-token-external-secret.yaml`
   (same directory as `github-oauth-secret.yaml`) pulls that key into a K8s Secret on
   `kind-man`, which `deployment.yaml` mounts as `KIND_DEV_SA_TOKEN` -
   `app-config.yaml`'s `kubernetes.clusterLocatorMethods` reads it via
   `${KIND_DEV_SA_TOKEN}` substitution.

If this cluster is ever rebuilt (the token Secret is regenerated, not preserved across
a `kind delete cluster`), repeat step 1-2 with the new value - same live-verification
discipline every other credential in this platform already needs.
