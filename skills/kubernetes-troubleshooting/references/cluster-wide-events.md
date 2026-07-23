# Cluster-wide restart events (many pods, one cause)

When lots of pods across several nodes all restarted at once, the culprit is almost
never the pods — it is one event underneath them: a node reboot, an `rke2`/`k3s` or
kubelet service restart, or planned maintenance. Recognising this saves you from
"debugging" thirty healthy workloads one by one.

The signature is correlation in time and kind, not any single pod:

```bash
# containers whose LAST termination clustered around the same moment, by node
# (replace the date with the window you are investigating)
kubectl get pods -A -o json | jq -r '
  .items[] | .spec.nodeName as $n | .status.containerStatuses[]?
  | select(.lastState.terminated.finishedAt // "" | startswith("2026-07-20"))
  | $n' | sort | uniq -c
kubectl get pods -n kube-system -o wide | grep kube-proxy   # AGE resets on node/service restart
```

Tell-tale signs it was an event, not a fault:

- **Many containers share one `finishedAt`** — a simultaneous kill, not thirty
  independent crashes.
- **Exit code `255` with reason `Unknown`** — an ungraceful kill (the process was
  taken down with the node/kubelet), not an application crash with its own exit code.
- **Static pods like `kube-proxy` show a fresh AGE with `0` restarts** — they were
  *recreated* when the node/service came back, not restarted in place.

A real fault staggers across nodes and leaves an error trail; a reboot or upgrade is
simultaneous and clean, and everything comes back `Ready`. If it was coordinated and
recovered, confirm it was expected maintenance and move on — there is nothing to fix.
