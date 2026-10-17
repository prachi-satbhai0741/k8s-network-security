#!/usr/bin/env sh
# Network policy simulation: end-to-end test runner.
#
# Usage:
#   sh scripts/run-tests.sh            run all phases without stopping
#   PAUSE=1 sh scripts/run-tests.sh    pause after each phase (for screenshots)
#
# The script is re-runnable: it removes existing NetworkPolicies before starting.

set -u

NS="network-security-demo"
EXT_NS="network-security-external"
BURST=30
PASS=0
FAIL=0

BACKEND_URL="http://backend"
BACKEND_X_NS_URL="http://backend.${NS}.svc.cluster.local"
EXTERNAL_URL="http://external-service.${EXT_NS}.svc.cluster.local"

section() {
  printf '\n==== %s ====\n' "$1"
}

pause() {
  if [ "${PAUSE:-0}" = "1" ]; then
    printf '\nCapture the screenshot now, then press Enter to continue... '
    read -r _unused
  fi
}

http_get() {
  # args: namespace pod url
  kubectl -n "$1" exec "$2" -- wget -q -O- -T 5 "$3" 2>/dev/null
}

expect_allowed() {
  # args: description namespace pod url
  out=$(http_get "$2" "$3" "$4")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    title=$(printf '%s' "$out" | grep -o '<title>.*</title>' | head -n 1)
    echo "[PASS] $1 -> allowed (${title:-response received})"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $1 -> blocked, but access was expected"
    FAIL=$((FAIL + 1))
  fi
}

expect_blocked() {
  # args: description namespace pod url
  if http_get "$2" "$3" "$4" >/dev/null; then
    echo "[FAIL] $1 -> allowed, but it should be blocked (verify the CNI enforces NetworkPolicies)"
    FAIL=$((FAIL + 1))
  else
    echo "[PASS] $1 -> blocked (connection timed out or refused)"
    PASS=$((PASS + 1))
  fi
}

burst() {
  # Sends BURST sequential requests from a pod and prints how many succeeded.
  # args: namespace pod url
  kubectl -n "$1" exec "$2" -- sh -c \
    "ok=0; i=0; while [ \$i -lt $BURST ]; do if wget -q -O /dev/null -T 1 $3; then ok=\$((ok+1)); fi; i=\$((i+1)); done; echo \$ok" \
    2>/dev/null
}

logged_requests() {
  # Counts backend access-log lines originating from the given pod's IP.
  # args: pod
  ip=$(kubectl -n "$NS" get pod "$1" -o jsonpath='{.status.podIP}')
  kubectl -n "$NS" logs deploy/backend 2>/dev/null | grep -c "^${ip} "
}

apply_policy() {
  kubectl apply -f "$1"
  sleep 5
}

# ---------------------------------------------------------------------------
section "Phase 0: Reset"
kubectl -n "$NS" delete networkpolicy --all --ignore-not-found
sleep 3
kubectl -n "$NS" get pods --show-labels
pause

# ---------------------------------------------------------------------------
section "Phase 1: Baseline (no policies, all traffic permitted)"
expect_allowed "frontend -> backend"                  "$NS"     frontend         "$BACKEND_URL"
expect_allowed "untrusted-client -> backend"          "$NS"     untrusted-client "$BACKEND_URL"
expect_allowed "external-client (other ns) -> backend" "$EXT_NS" external-client  "$BACKEND_X_NS_URL"
expect_allowed "frontend -> external-service"         "$NS"     frontend         "$EXTERNAL_URL"
pause

# ---------------------------------------------------------------------------
section "Phase 2: Request burst from untrusted-client, before any policy"
ok=$(burst "$NS" untrusted-client "$BACKEND_URL")
ok=${ok:-0}
echo "Requests sent: $BURST, succeeded: $ok"
echo "Backend access-log entries from untrusted-client: $(logged_requests untrusted-client)"
if [ "$ok" -gt 0 ]; then
  echo "[PASS] Burst reached the backend (expected without a policy)"
  PASS=$((PASS + 1))
else
  echo "[FAIL] Burst did not reach the backend, baseline is not valid"
  FAIL=$((FAIL + 1))
fi
pause

# ---------------------------------------------------------------------------
section "Phase 3: Default-deny ingress"
apply_policy manifests/04-default-deny-ingress.yaml
expect_blocked "frontend -> backend"         "$NS" frontend         "$BACKEND_URL"
expect_blocked "untrusted-client -> backend" "$NS" untrusted-client "$BACKEND_URL"
kubectl -n "$NS" get networkpolicy
pause

# ---------------------------------------------------------------------------
section "Phase 4: Allow-list the frontend"
apply_policy manifests/05-allow-frontend-to-backend.yaml
expect_allowed "frontend -> backend"                   "$NS"     frontend         "$BACKEND_URL"
expect_blocked "untrusted-client -> backend"           "$NS"     untrusted-client "$BACKEND_URL"
expect_blocked "external-client (other ns) -> backend" "$EXT_NS" external-client  "$BACKEND_X_NS_URL"
kubectl -n "$NS" get networkpolicy
pause

# ---------------------------------------------------------------------------
section "Phase 5: Request burst from untrusted-client, after the policy"
before=$(logged_requests untrusted-client)
ok=$(burst "$NS" untrusted-client "$BACKEND_URL")
ok=${ok:-0}
after=$(logged_requests untrusted-client)
echo "Requests sent: $BURST, succeeded: $ok"
echo "New backend access-log entries from untrusted-client: $((after - before))"
if [ "$ok" -eq 0 ]; then
  echo "[PASS] Burst was fully blocked at the network layer"
  PASS=$((PASS + 1))
else
  echo "[FAIL] $ok requests got through"
  FAIL=$((FAIL + 1))
fi
pause

# ---------------------------------------------------------------------------
section "Phase 6: Egress restriction on the frontend"
apply_policy manifests/06-frontend-egress-policy.yaml
expect_allowed "frontend -> backend (permitted egress)"       "$NS" frontend "$BACKEND_URL"
expect_blocked "frontend -> external-service (denied egress)" "$NS" frontend "$EXTERNAL_URL"
kubectl -n "$NS" get networkpolicy
pause

# ---------------------------------------------------------------------------
section "Summary"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -ne 0 ]; then
  echo "One or more checks failed. Confirm the CNI (Calico or Cilium) is running and enforcing policies." >&2
  exit 1
fi
echo "All checks passed."
