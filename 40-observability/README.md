# 40-observability

Prometheus/Grafana/Tempo/Loki stack — per `gitops-strategy.md` §3.

## Current state (documented, not yet re-templated or adopted)

Six Helm releases already live in the `observability` namespace, several with
substantial custom values (`kube-prometheus-stack` wires real Grafana datasource
integration to Loki/Tempo/Thanos) - capturing all of them with the same fidelity as
`10-crds-operators` (exact extracted values, live-verified non-destructive adoption) is
real work, deliberately scoped out of this pass rather than rushed:

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
