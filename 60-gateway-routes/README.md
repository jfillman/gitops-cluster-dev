# 60-gateway-routes

Gateway API `HTTPRoute`s exposing this cluster's UI-bearing Services through the
kiac-installed Gateway (`kiac`, ns `kiac-gateway`, `GatewayClass traefik` →
`traefik.io/gateway-controller`), reached via `kiac-dev`'s control-plane VM IP
(`192.168.64.5`) on port 80.

Each `HTTPRoute` lives in the same namespace as its backend `Service` — Gateway API
requires that unless a `ReferenceGrant` explicitly allows cross-namespace
`backendRefs`, and none of these need one. That's why `application.yaml` is a
multi-namespace directory source rather than one fixed `destination.namespace`.

| Hostname | Service | Namespace |
|---|---|---|
| `argocd.dev.kiac.local` | `argocd-server` | `argocd` |
| `argocd-apps.dev.kiac.local` | `argocd-apps-server` | `argocd-apps` |
| `grafana.dev.kiac.local` | `kube-prometheus-stack-grafana` | `observability` |
| `minio-console.dev.kiac.local` | `minio-console` | `observability` |
| `infisical.dev.kiac.local` | `infisical-infisical-standalone-infisical` | `infisical` |
| `tekton.dev.kiac.local` | `tekton-dashboard` | `tekton-pipelines` |

To reach these from the Mac, point them at the gateway IP, e.g. in `/etc/hosts`:

```
192.168.64.5 argocd.dev.kiac.local argocd-apps.dev.kiac.local grafana.dev.kiac.local minio-console.dev.kiac.local infisical.dev.kiac.local tekton.dev.kiac.local
```

HTTP only — the `kiac` Gateway only has an `http`/port-80 listener today, no TLS
listener. `kiac-prod`'s equivalent routes live in `gitops-cluster-kind-prod`'s own
`50-gateway-routes/`, using the same Service names but a `.prod.kiac.local` suffix so
both clusters' routes can resolve from one `/etc/hosts` at the same time.

Both ArgoCD instances' `server.insecure: "true"` is set in `01-argocd-platform/`
(`install.yaml`'s `argocd-cmd-params-cm` for the `argocd` instance,
`argocd-apps-install/application.yaml`'s `configs.params` for `argocd-apps`) —
without it, `argocd-server` redirects plain HTTP to HTTPS by default, which the
Gateway's HTTP-only listener can't follow.

Deliberately **not** routed here: `backstage-system` — namespace exists, nothing
deployed into it yet.
