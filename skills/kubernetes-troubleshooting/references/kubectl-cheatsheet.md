# Reference: kubectl Inspection Cheatsheet

Grouped by problem area. Everything in the "Inspect" blocks is read-only and safe.
The "Mutate" section changes cluster state — never run those during triage until
the cause is understood.

## Wide triage (start here)

```bash
kubectl get pods -A -o wide                         # all pods, all namespaces, with nodes
kubectl get nodes -o wide                            # node status and addresses
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl get pods -A --field-selector=status.phase!=Running
```

## A specific pod

```bash
kubectl describe pod <pod> -n <ns>                   # status, conditions, events — read first
kubectl logs <pod> -n <ns>                           # current container
kubectl logs <pod> -n <ns> --previous                # the instance that crashed
kubectl logs <pod> -n <ns> -c <container>            # named container
kubectl get pod <pod> -n <ns> -o yaml                # full spec + status
kubectl get pod <pod> -n <ns> -o json | jq '.status' # machine-readable status
```

## Scheduling

```bash
kubectl describe pod <pod> -n <ns> | sed -n '/Events:/,$p'
kubectl describe node <node> | sed -n '/Allocated resources/,/Events/p'
kubectl get nodes -o json | jq '.items[].spec.taints'
kubectl get node <node> --show-labels
```

## Storage

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv
kubectl get storageclass
kubectl describe pod <pod> -n <ns> | grep -A5 -i mount
```

## Networking

```bash
kubectl get svc <svc> -n <ns> -o wide
kubectl describe svc <svc> -n <ns>
kubectl get endpoints <svc> -n <ns>                  # empty = no ready pods match selector
kubectl get networkpolicy -A
kubectl get pods -n <ns> --show-labels               # compare labels to svc selector

# DNS check from a throwaway pod (self-deletes)
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup <svc>.<ns>.svc.cluster.local

# CoreDNS health
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Nodes

```bash
kubectl describe node <node> | sed -n '/Conditions:/,/Addresses:/p'
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
kubectl top nodes                                    # requires metrics-server
kubectl top pods -A                                  # requires metrics-server
```

## Resource usage

```bash
kubectl top pod <pod> -n <ns>
kubectl top pod -n <ns> --containers
kubectl describe pod <pod> -n <ns> | grep -A2 -i 'limits\|requests'
```

## Mutate — only after the cause is known

These change state. During triage they destroy evidence; use them as the *fix*, not
the investigation.

```bash
kubectl rollout restart deployment/<name> -n <ns>    # rolling restart, keeps history
kubectl delete pod <pod> -n <ns>                     # let the controller recreate it
kubectl scale deployment/<name> -n <ns> --replicas=<n>
kubectl edit <resource>/<name> -n <ns>
kubectl cordon <node>                                # stop new pods scheduling here
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data  # evacuate before maintenance

# Last resort, only when the underlying resource is confirmed gone:
kubectl delete pod <pod> -n <ns> --force --grace-period=0
```

## Handy patterns

```bash
# Watch a rollout live
kubectl rollout status deployment/<name> -n <ns>

# Everything owned by a label
kubectl get all -n <ns> -l app=<name>

# Events for one object only
kubectl get events -n <ns> --field-selector involvedObject.name=<pod>

# Exec into a running container to test from inside
kubectl exec -it <pod> -n <ns> -- sh
```
