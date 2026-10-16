#!/usr/bin/env sh
set -eu

namespace="network-security-demo"

echo "== Baseline: both clients should reach the backend =="
kubectl -n "$namespace" exec frontend -- wget -qO- --timeout=5 http://backend
kubectl -n "$namespace" exec untrusted-client -- wget -qO- --timeout=5 http://backend

echo "== Applying NetworkPolicy =="
kubectl apply -f manifests/04-backend-ingress-policy.yaml

echo "== Protected: frontend should still reach the backend =="
kubectl -n "$namespace" exec frontend -- wget -qO- --timeout=5 http://backend

echo "== Protected: unauthorised client should be blocked =="
if kubectl -n "$namespace" exec untrusted-client -- wget -qO- --timeout=5 http://backend; then
  echo "Unexpected access: check whether your CNI enforces NetworkPolicies." >&2
  exit 1
else
  echo "Expected result: unauthorised client was blocked."
fi
