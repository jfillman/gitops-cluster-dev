# 40-observability

Prometheus/Grafana/Tempo/Loki stack — per `gitops-strategy.md` §3.

## Real, built, live-verified on `kind-dev` (2026-08-13)

`kube-prometheus-stack/application.yaml` - **deliberately NOT the same as the
kind-observe values documented below.** `kind-dev` has only ever run a minimal
kube-prometheus-stack + HolmesGPT (Loki/Tempo/Thanos/MinIO/otel-collector explicitly
skipped since `idp_session_phase2_holmesgpt` - "not needed for this proof"), and this
Application matches that scope: plain Prometheus + Grafana + Alertmanager, no Thanos
sidecar/objstore, no Loki/Tempo datasources. Release name is exactly
`kube-prometheus-stack` so the chart's own default `release:`-label
ServiceMonitor/PrometheusRule selectors line up with what
idp-service-catalog's SLO Composition and `idp-application`'s own
`serviceMonitor.additionalLabels` already assumed - confirmed against a real install
now, not left as an unconfirmed placeholder. Reused the same
`ServerSideApply=true` fix `01-argocd/`/`external-secrets/` needed (kube-prometheus-
stack's CRDs are large enough to hit the same annotation-size limit).

**HolmesGPT is not built here yet** - its real values (narrower toolset, dropped
Grafana/Loki+Tempo, `github` MCP addon - see `idp_session_phase2_holmesgpt`) were
never captured into a file anywhere findable on disk, so reconstructing it accurately
needs real work, not a guess. Deferred, not forgotten.

## kind-observe's own state (documented, not yet re-templated or adopted)

This section describes `kind-observe` specifically, the cluster this repo's own
top-level README names as its primary target - **not** `kind-dev` above. Six Helm
releases already live in the `observability` namespace there, several with
substantial custom values (`kube-prometheus-stack` wires real Grafana datasource
integration to Loki/Tempo/Thanos) - capturing all of them with the same fidelity as
`10-crds-operators` (exact extracted values, live-verified non-destructive adoption) is
real work, deliberately scoped out of this pass rather than rushed. **Also true as of
this same pass: `kind-observe`'s own ArgoCD has no Applications in it yet either
(confirmed live) - the "adopted" pieces documented in `10-crds-operators/` were
values-matched, not actually synced there. `kind-dev`, bootstrapped fresh this pass,
is the first cluster this repo's Applications have actually been live-synced
against.**

| Release | Chart | Version |
|---|---|---|
| `kube-prometheus-stack` | `kube-prometheus-stack` | 87.19.1 (app v0.92.1) |
| `loki` | `loki` | 7.1.0 (app 3.6.8) |
| `minio` | `minio` | 5.4.0 |
| `otel-collector` | `opentelemetry-collector` | 0.165.0 |
| `tempo` | `tempo` | 1.24.4 (app 2.9.0) |
| `thanos` | `thanos` | 17.3.1 (app 0.39.2) |

**`holmesgpt`** (chart `holmes` 0.38.0) also runs in its own `holmesgpt` namespace —
found during this cluster inventory, not previously known to any `idp` design doc.
Robusta's AI-powered K8s troubleshooting/root-cause tool — directly adjacent to the
`ai-rollout` diagnosis-job mechanism (goal 9, "AI embedded at the control-plane layer")
that's already been folded into the `idp` plan. **Not yet understood well enough to say
whether it's meant to integrate with that work or is a separate exploration** — worth
asking about directly rather than assuming either way before Phase 2's AI-triage design
work happens.
