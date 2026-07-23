---
name: kubernetes-troubleshooting
description: >-
  Systematic triage of failing Kubernetes workloads using kubectl. Use when a pod
  is Pending, CrashLoopBackOff, ImagePullBackOff, OOMKilled, Error, or stuck
  Terminating; when a PersistentVolumeClaim will not bind; when a Service returns
  no endpoints or connections are refused; when DNS resolution fails inside the
  cluster; or when a node is NotReady or reporting disk, memory, or PID pressure.
  Use when someone asks why a workload is not running, not reachable, or not
  scheduling. Use it too for proactive health checks — when someone asks "is the
  cluster OK?" or whether something is healthy even though nothing is obviously
  failing, since a green-looking cluster can still hide restart loops, filling
  disks, and lost redundancy. Prefer this skill over guessing: it defines the
  order to inspect things so evidence is gathered before any change is made.
allowed-tools: Bash Read Grep
license: MIT
---

# Kubernetes Troubleshooting

Triage failing Kubernetes workloads in a disciplined order. The goal is to reach
the cause with the fewest, cheapest observations, and to gather evidence *before*
taking any destructive action.

## Prime directive: observe before you act

Do not delete, restart, scale, or `--force` anything until the cause is
understood. A stuck pod, a pending PVC, a NotReady node — each is evidence. The
most common way to turn a five-minute diagnosis into a two-hour one is to destroy
the state that would have explained the problem. Deleting a pod stuck in
`Terminating` with `--force --grace-period=0`, for example, removes the very thing
you needed to inspect and can leave the underlying resource (a volume attachment,
a finalizer) in an inconsistent state.

## Step 0: locate the problem

Always start wide, then narrow. Establish *what* is broken before asking *why*.

```bash
# anything not fully ready: containers not all up, or status not Running/Completed
kubectl get pods -A --no-headers | \
  awk '{split($3,a,"/"); if (a[1]!=a[2] || ($4!="Running" && $4!="Completed")) print}'
kubectl get nodes -o wide                                  # node health at a glance
kubectl get events -A --sort-by=.lastTimestamp | tail -30  # what changed recently
```

The `awk` filter is deliberate rather than a `grep -E '([0-9]+)/\1'` backreference:
not every `grep` (BSD grep, ugrep, busybox) supports backreferences, and the awk
version states the intent plainly — a pod is interesting if its ready count differs
from its container count, or it is not in a terminal-healthy phase.

Events are the single most under-used signal. They are cluster-wide, time-ordered,
and usually name the cause in plain language. Read them before anything else.

**Green is not the same as healthy.** When the question is "is the cluster OK?" and
nothing is in a failing phase, the interesting problems are the slow-burn ones that
have not caused an outage *yet*: pods that are `Running` but restart on a cadence,
disks quietly filling, redundancy already lost. Do not stop at "all pods Running."
Also scan restart trends and capacity headroom:

```bash
kubectl get pods -A --sort-by=.status.containerStatuses[0].restartCount | tail -20
kubectl top nodes                                          # needs metrics-server
```

A high restart total is a prompt to investigate, not a verdict — read the next
section before treating it as a fire.

## Step 1: describe before you log

For any unhealthy object, `describe` first. It shows status, conditions, recent
events for that specific object, and — for pods — why the kubelet is unhappy.

```bash
kubectl describe pod <pod> -n <ns>
```

Only reach for logs once `describe` tells you the container actually started.
Logs from a container that never started are empty or misleading.

```bash
kubectl logs <pod> -n <ns>                 # current container
kubectl logs <pod> -n <ns> --previous      # the instance that just crashed
kubectl logs <pod> -n <ns> -c <container>  # a specific container in a multi-container pod
```

The `--previous` flag is the one people forget. In a CrashLoopBackOff the running
container is the *restart*; the error you want is in the container that died.

## Decision table

| Symptom (`kubectl get pods`) | Most likely area | Go to |
|---|---|---|
| `Pending` | Scheduling: resources, PVC, taints, affinity | §Scheduling |
| `ContainerCreating` (stuck) | Volume mount, image pull, secret/configmap missing | §Volumes, §Images |
| `ImagePullBackOff` / `ErrImagePull` | Registry auth, image name/tag, network | §Images |
| `CrashLoopBackOff` | App exits on startup; config, dependency, migration | §CrashLoop |
| `OOMKilled` (in describe) | Memory limit too low, or a leak | §Resources |
| `Error` / `Completed` (unexpected) | Wrong command, failed init, exit code | §CrashLoop |
| `Terminating` (stuck) | Finalizer, volume detach, node gone | §Terminating |
| `Running` but not reachable | Service, endpoints, network policy, DNS | §Networking |
| Node `NotReady` | kubelet, CNI, disk/memory/PID pressure | §Nodes |

## Reading restart counts (a big number is not a fire)

The `RESTARTS` column is a *cumulative total over the pod's whole life*, not a rate.
A DaemonSet pod that has been up for 500 days at 580 restarts has averaged barely
one a day — utterly benign — yet the raw number looks alarming. The single most
common false alarm is treating a large cumulative count as an active crash loop and
"fixing" it by deleting the pod, destroying the evidence for no reason.

Before you believe a restart count, place it in time. Three signals separate a live
loop from old history:

```bash
kubectl get pod <pod> -n <ns> -o wide            # AGE, and "N (Xd ago)" in RESTARTS
kubectl describe pod <pod> -n <ns> | grep -A4 'Last State'   # when it last died
```

- **`RESTARTS` shows `(3d ago)`** and the container's `Started` timestamp is days
  back → the pod is *stable now*; the count is accumulated history. Not your
  problem, however big it is.
- **`(30s ago)` / `(2m ago)`** and the count is climbing between two `get` calls →
  a genuine active loop. Now go to §CrashLoop.
- **Count ≈ pod AGE in days** → a slow, chronic restarter (a flapping probe, a
  periodic OOM). Worth a look, but not an emergency — read the trend, not the total.

## Scheduling (Pending)

A `Pending` pod has not been placed on a node. The scheduler records why in events.

```bash
kubectl describe pod <pod> -n <ns> | sed -n '/Events:/,$p'
```

Read the message literally. Common causes and what they mean:

- **`Insufficient cpu` / `Insufficient memory`** — no node has enough allocatable
  headroom for the pod's *requests* (not limits). Check requests vs. node capacity:
  `kubectl describe node <node> | sed -n '/Allocated resources/,/Events/p'`.
- **`pod has unbound immediate PersistentVolumeClaims`** — the PVC is not bound; the
  storage problem is upstream of scheduling. Go to §Volumes.
- **`node(s) had untolerated taint`** — the pod lacks a toleration for a node taint
  (control-plane nodes, dedicated nodes). Inspect with
  `kubectl get nodes -o json | jq '.items[].spec.taints'`.
- **`node(s) didn't match Pod's node affinity/selector`** — `nodeSelector` or
  affinity rules match no node. Compare pod affinity to node labels.
- **`0/N nodes are available`** with a mix of reasons — read each; the scheduler
  lists every node's disqualifying reason.

## Images (ImagePullBackOff / ErrImagePull)

```bash
kubectl describe pod <pod> -n <ns> | grep -A5 -i 'failed\|pull'
```

- **`manifest unknown` / `not found`** — wrong image name or tag. Verify the exact
  reference; a missing or moved tag is the usual culprit.
- **`unauthorized` / `authentication required`** — the pull secret is missing,
  wrong, or not referenced. Confirm `imagePullSecrets` on the pod/serviceaccount
  and that the secret exists in the same namespace.
- **`dial tcp ... timeout`** — the node cannot reach the registry. Network or DNS
  problem at the node level, not an auth problem.

## CrashLoop (CrashLoopBackOff / Error)

The container starts and exits. The evidence is in the *previous* logs and the exit
code.

```bash
kubectl logs <pod> -n <ns> --previous
kubectl describe pod <pod> -n <ns> | grep -A3 'Last State'
```

- **Exit code 1 / app stack trace** — application-level: missing config, a
  dependency (DB, broker) not reachable, a failed migration. Read the trace.
- **Exit code 137** — SIGKILL, almost always OOMKilled. Go to §Resources.
- **Exit code 143** — SIGTERM; the pod was asked to stop. Usually not the root
  cause itself.
- **Init container failing** — `kubectl logs <pod> -n <ns> -c <init-container>`. The
  main container never runs until inits succeed.
- **Liveness probe killing a healthy app** — if the app logs look fine but it
  restarts on a fixed interval, suspect a too-aggressive `livenessProbe`. Check its
  `initialDelaySeconds` and `timeoutSeconds` in `describe`.

## Resources (OOMKilled)

```bash
kubectl describe pod <pod> -n <ns> | grep -i -A2 'oomkilled\|last state'
kubectl top pod <pod> -n <ns>          # requires metrics-server
```

`OOMKilled` means the container exceeded its memory *limit*. Two distinct causes,
and the fix differs:

- The limit is simply too low for legitimate usage → raise the limit.
- Memory grows without bound over time → a leak; raising the limit only delays the
  kill. Look at usage trend, not a single snapshot.

Note the difference between requests (used for scheduling) and limits (enforced at
runtime). OOMKills are about limits.

## Volumes (PVC won't bind / ContainerCreating)

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv | grep <pvc>
```

- **PVC `Pending`, event `no persistent volumes available` / `waiting for a
  volume to be created`** — no PV matches and none is being provisioned. Check the
  `storageClassName` exists (`kubectl get storageclass`) and that its provisioner
  is running.
- **PVC `Pending` with `WaitForFirstConsumer`** — this is normal; the volume binds
  only once a pod that uses it is scheduled. The real blocker is then the pod's
  scheduling (§Scheduling).
- **Pod stuck `ContainerCreating`, event `FailedMount` / `Unable to attach or
  mount volumes`** — the PVC is bound but the mount fails. Read the mount error:
  a node-level volume-attachment or CSI-driver problem, a wrong access mode
  (`ReadWriteOnce` volume demanded by pods on two nodes), or a stale attachment
  from a previous node.
- **PVC bound and mounted, but the volume misbehaves** (writes fail, it will not
  attach elsewhere, the provider disk is full) — the core objects look fine because
  the problem is *inside the storage provider*. Go to §Storage providers.

## Networking (Running but unreachable)

Work outward from the pod: does the Service select it, does it have endpoints, does
DNS resolve, does a network policy block it.

```bash
kubectl get endpoints <svc> -n <ns>          # empty = selector matches no ready pods
kubectl get svc <svc> -n <ns> -o wide
kubectl describe svc <svc> -n <ns>
```

- **Empty endpoints** — the Service `selector` does not match the pod labels, or the
  pods are not `Ready` (failing readiness probes are excluded from endpoints).
  Compare `svc.spec.selector` to the pod labels exactly.
- **Endpoints present, still unreachable** — suspect a `NetworkPolicy`. Default-deny
  policies silently drop traffic. List them:
  `kubectl get networkpolicy -A`.
- **DNS failures** (`could not resolve`, `no such host`) — test resolution from a
  throwaway pod:
  ```bash
  kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- \
    nslookup <svc>.<ns>.svc.cluster.local
  ```
  If that fails, check CoreDNS: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
  and its logs.
- **Wrong port** — the Service `targetPort` must match the container's actual
  listening port, not just the `port`.

## Terminating (stuck)

```bash
kubectl get pod <pod> -n <ns> -o json | jq '.metadata.finalizers, .metadata.deletionTimestamp'
```

- A **finalizer** is waiting on something (a controller cleaning up an external
  resource). The correct fix is to resolve what the finalizer waits for, not to
  strip it. Removing a finalizer by hand can orphan the resource it was protecting.
- The **node is gone** — if the node hosting the pod is `NotReady`/unreachable, the
  pod cannot confirm termination. Address the node first (§Nodes); the pod resolves
  once the node returns or is properly drained/deleted.
- Reserve `--force --grace-period=0` for the case where you have *confirmed* the
  underlying resource is already gone. It is a last resort, not a first move.

## Nodes (NotReady / pressure)

```bash
kubectl describe node <node> | sed -n '/Conditions:/,/Addresses:/p'
```

The conditions block names the problem directly:

- **`MemoryPressure` / `DiskPressure` / `PIDPressure` = True** — the node is out of
  the named resource and the kubelet is evicting pods. Free the resource (disk is
  the most common: image/log/ephemeral buildup) or reduce load on the node.
- **`Ready = Unknown`** — the kubelet stopped reporting. The node process is down,
  the machine is unreachable, or the CNI is broken so the node cannot talk to the
  control plane. Check the kubelet and the CNI pods on that node.
- **`Ready = False` with a CNI message** — the container network is not healthy on
  that node. Inspect the CNI daemonset pods (`kubectl get pods -n kube-system -o wide`
  and filter to the node). A CNI failure presents as pods stuck
  `ContainerCreating` cluster-wide and nodes flapping NotReady.

Beware the `DiskPressure` trap: the kubelet condition tracks only *its own* disk —
the root/ephemeral filesystem. A storage provider (Longhorn, Ceph, a dedicated data
mount) lives on a **different** disk the kubelet knows nothing about. That disk can
be 100% full while the node cheerfully reports `DiskPressure = False`. If workloads
complain about storage but node conditions look clean, the full disk is somewhere
the kubelet is not looking — see §Storage providers.

## Cluster-wide restart events (many pods, one cause)

When lots of pods across several nodes all restarted at once, the culprit is almost
never the pods — it is one event underneath them: a node reboot, an `rke2`/`k3s` or
kubelet service restart, or planned maintenance. Recognising this saves you from
"debugging" thirty healthy workloads one by one.

The signature is correlation in time and kind, not any single pod:

```bash
# containers whose LAST termination clustered around the same moment, by node
kubectl get pods -A -o json | jq -r '
  .items[] | .spec.nodeName as $n | .status.containerStatuses[]?
  | select(.lastState.terminated.finishedAt // "" | startswith("2026-07-20"))
  | $n' | sort | uniq -c
kubectl get pods -n kube-system -o wide | grep kube-proxy   # AGE resets on node/service restart
```

Tell-tale signs it was an event, not a fault: many containers share one
`finishedAt`; the exit code is `255` with reason `Unknown` (an ungraceful kill, not
an app crash); static pods like `kube-proxy` show a fresh AGE with `0` restarts
(recreated, not restarted). A real fault staggers across nodes and leaves an error
trail; a reboot/upgrade is simultaneous and clean, and everything comes back
`Ready`. If it was coordinated and recovered, confirm it was expected maintenance
and move on — there is nothing to fix.

## Storage providers (Longhorn, Ceph, and other CSI)

Core Kubernetes objects (`pod`, `pvc`, `pv`) tell you a volume is *bound and
mounted* — they say almost nothing about the provider's *internal* health: replica
placement, snapshot buildup, per-disk free space, degraded/rebuilding volumes. That
health lives in the provider's own CRDs, and a disk-full or degraded-volume problem
is invisible from `kubectl get pods` alone. This is often the real cause behind
"the node disk is full but `DiskPressure` is False" and behind volumes that are
attached yet misbehaving.

When storage is the suspect, read the provider's resources, and — when you need to
see what is actually consuming a data disk without SSH — inspect the filesystem from
a pod that already host-mounts it. Both techniques (including the exact Longhorn
CRDs and the `du`-via-instance-manager trick used to find snapshot bloat) are in
`references/storage-provider-troubleshooting.md`.

## When you have the cause

State it plainly before acting: *what* is broken, *why*, and the *smallest* change
that fixes it. Prefer a targeted fix (correct a selector, raise a limit, fix an
image tag) over a broad one (delete and recreate). If a restart is genuinely the
fix, say why the state you are destroying is no longer needed.

Then verify the fix actually took — submitting a change is not the same as it
landing, and starting an operation is not the same as it finishing:

- **Confirm the change persisted on the object**, don't assume the apply worked.
  Re-read the field you set (`kubectl get ... -o jsonpath`). Admission webhooks can
  silently mutate or reject values — a provider may cap, round, or refuse a setting
  and only tell you in the rejection message, so *read that message* rather than
  retrying blind.
- **Wait out asynchronous operations.** Many fixes queue background work — a volume
  snapshot purge, a PVC resize, a rollout, an image GC. Space is not reclaimed and
  health is not restored the instant the command returns. Poll the relevant status
  (`rollout status`, the provider's progress field, `df`) until it genuinely
  completes before reporting success.

## Reference

Deeper material lives alongside this file:

- `references/pod-states.md` — every pod phase and container state, what each means,
  and the exit codes worth memorizing.
- `references/kubectl-cheatsheet.md` — the inspection commands used above, grouped by
  problem area, safe to run (read-only) versus mutating.
- `references/storage-provider-troubleshooting.md` — inspecting CSI storage
  providers (Longhorn/Ceph) via their CRDs, the disk-full-from-snapshots pattern,
  and how to see what is eating a data disk without SSH.
