# Kubernetes Network Policy Security Simulation

## Objective

Demonstrate distributed access control in a Kubernetes cluster by enforcing a default-deny posture, allow-listing a single authorised client, restricting egress, and mitigating an unauthorised request burst, with before and after evidence for each control.

## Topology

| Resource | Namespace | Role |
|---|---|---|
| backend (nginx) and Service | network-security-demo | Protected service |
| frontend (busybox) | network-security-demo | Authorised client |
| untrusted-client (busybox) | network-security-demo | Unauthorised client, source of the request burst |
| external-client (busybox) | network-security-external | Cross-namespace unauthorised client |
| external-service (nginx) and Service | network-security-external | Destination used to test frontend egress restriction |

## Policies

| File | Policy | Effect |
|---|---|---|
| 04-default-deny-ingress.yaml | default-deny-ingress | Blocks all ingress to every pod in the namespace |
| 05-allow-frontend-to-backend.yaml | allow-frontend-to-backend | Permits only pods labelled app=frontend to reach the backend on TCP 80 |
| 06-frontend-egress-policy.yaml | restrict-frontend-egress | Frontend may reach only the backend and cluster DNS |

## Prerequisite: a CNI that enforces NetworkPolicies

A NetworkPolicy resource has no effect unless the cluster network plugin enforces it. Calico and Cilium do. The default kind CNI does not.

### Option A: Minikube with Calico

```bash
minikube start --cni=calico
```

### Option B: kind with Calico

```bash
kind create cluster --config kind/kind-config.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
kubectl -n kube-system rollout status daemonset/calico-node
```

## Run

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-backend.yaml
kubectl apply -f manifests/02-frontend.yaml
kubectl apply -f manifests/03-untrusted-client.yaml
kubectl apply -f manifests/07-external-namespace.yaml

kubectl wait -n network-security-demo --for=condition=Ready pod --all --timeout=180s
kubectl wait -n network-security-external --for=condition=Ready pod --all --timeout=180s

sh scripts/run-tests.sh
```

To pause after each phase and capture screenshots:

```bash
PAUSE=1 sh scripts/run-tests.sh
```

The script applies the policies in order (04, 05, 06) and is safe to re-run.

## Simulation phases

1. Reset and list pods with labels.
2. Baseline: every client can reach the backend.
3. Request burst from the untrusted client succeeds (no policy).
4. Apply default-deny ingress: all clients, including the frontend, are blocked.
5. Apply the allow-list: only the frontend succeeds; the untrusted and cross-namespace clients are blocked.
6. Repeat the request burst: all requests are blocked.
7. Apply the frontend egress policy: backend reachable, external service blocked.

## Limitations

- The request burst is a lightweight simulation of an unauthorised flood from a single source. It demonstrates that traffic is dropped at the network layer; it is not a volumetric DoS test.
- NetworkPolicies operate at layers 3 and 4. They do not provide authentication, encryption, or application-layer filtering.
- Results depend on the CNI in use.

## Cleanup

```bash
kubectl delete namespace network-security-demo network-security-external
```
