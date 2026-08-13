# 20-service-catalog

Pins `idp-service-catalog`'s XRDs/Compositions to a version, per `gitops-strategy.md`
§3 — done, wired into the app-of-apps root and live-verified 2026-08-13. See
`idp-service-catalog/application.yaml`'s own header for the exact sync scope (`xrds/`
+ each `compositions/<name>/composition.yaml`, not `charts/idp-application` or
`functions/` — see that file's comments for why).

`idp-application` itself is NOT installed from here — it's a chart future
Compositions render per app-release into `gitops-<app-name>` repos, not a
cluster-wide install (see `idp-service-catalog/charts/idp-application/README.md`).
