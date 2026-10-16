# Kubernetes Network Policy Security Simulation

**Academic title:** Simulation of Network Security and Access Control Using Kubernetes Network Policies

## Objective

Demonstrate Kubernetes pod-to-pod access control by allowing an authorised frontend pod to reach a backend service while blocking an unauthorised pod.

## Important prerequisite

Your Kubernetes network plugin (CNI) must enforce NetworkPolicies. Calico and Cilium do; a policy resource alone is not enough.

## Simulation flow

1. Deploy the backend, authorised frontend, and unauthorised client.
2. Test both clients before the policy: both should succeed.
3. Apply the NetworkPolicy.
4. Test again: frontend succeeds; unauthorised client times out or fails.

## Run

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-backend.yaml
kubectl apply -f manifests/02-frontend.yaml
kubectl apply -f manifests/03-untrusted-client.yaml
kubectl wait -n network-security-demo --for=condition=Ready pod -l app=backend --timeout=120s
kubectl wait -n network-security-demo --for=condition=Ready pod -l app=frontend --timeout=120s
kubectl wait -n network-security-demo --for=condition=Ready pod -l app=untrusted --timeout=120s
sh scripts/run-tests.sh
```

## Cleanup

```bash
kubectl delete namespace network-security-demo
```
