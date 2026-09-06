#!/bin/bash

# start up dev cluster with kaic
# cpus/cp-memory bumped 5/20G -> 7/28G on 2026-09-05: the single control-plane VM
# was sitting at 82-84% CPU / 79-84% memory at rest (see memory: kiac-dev structural
# capacity incidents 2026-09-03/04), which delayed kubelet pod-status propagation
# enough to cause real failures (ArgoCD repo-server crash-loops, a testkube
# watch-controller false-abort on an already-completed pod). Resized live via
# stop -> edit VM resource config -> restart apiserver -> start -> `kiac resume`,
# not a delete+recreate, so no data was lost - this flag change just keeps a future
# real recreate consistent with the resized VM.
#
# Bumped again 7/28G -> 10/38G same day, before the Rekor+Trillian+MySQL install
# (docs/admin/provenance-policy.md): even after the first bump, the node was still at
# 76-86% CPU/memory at rest, and MySQL/Trillian's first-boot init is the exact workload
# that destabilized this stack five times previously under podman. Same live-resize
# procedure, no data loss. kiac-man is retired from capacity planning - topology is now
# just dev + prod.
 kiac create cluster --name dev --workers 0 --cni cilium --kernel full --cpus 10 --cp-memory 38G --gateway
