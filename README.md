# Kubernetes Network Policy Security Simulation

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

## Screenshots for the report

1. `kubectl get pods -n network-security-demo --show-labels`
2. Both baseline connection tests succeeding
3. `kubectl get networkpolicy -n network-security-demo`
4. Frontend access succeeding after the policy
5. Unauthorised-client access failing after the policy

## Cleanup

```bash
kubectl delete namespace network-security-demo network-security-external
```
