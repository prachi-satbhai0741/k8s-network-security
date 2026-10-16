# Kubernetes Network Policy Security Simulation

**Academic title:** Simulation of Network Security and Access Control Using Kubernetes Network Policies

## Objective

Demonstrate Kubernetes pod-to-pod access control by allowing an authorised frontend pod to reach a backend service while blocking an unauthorised pod.

## Unit V mapping

| Unit V concept | Demonstration in this project |
| --- | --- |
| Access Control | Only the pod labelled `app: frontend` is allowed to contact the backend. |
| Firewalls | A Kubernetes `NetworkPolicy` filters inbound backend traffic. |
| Security Policies and Mechanisms | The YAML policy defines and enforces the allowed communication rule. |
| Authorization Management | Pod labels identify the authorised workload. |
| Cloud Service-Oriented Architecture | Frontend and backend run as separate services in a cloud-native system. |

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

## Screenshots for the report

1. `kubectl get pods -n network-security-demo --show-labels`
2. Both baseline connection tests succeeding
3. `kubectl get networkpolicy -n network-security-demo`
4. Frontend access succeeding after the policy
5. Unauthorised-client access failing after the policy

## Cleanup

```bash
kubectl delete namespace network-security-demo
```
