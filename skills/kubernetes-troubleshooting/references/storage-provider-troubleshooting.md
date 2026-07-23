# Storage-provider troubleshooting (Longhorn, Ceph, and other CSI)

Core objects (`pod`, `pvc`, `pv`) confirm a volume is *bound and mounted*. They do
not report the provider's internal health — replica placement, per-disk free space,
snapshot buildup, degraded or rebuilding volumes. When a storage problem does not
show up in `kubectl get pods`, that health is in the provider's own CRDs. This file
covers the two things you most often need: reading provider state, and seeing what
is actually consuming a data disk.

## Contents

- [The disk-full-but-DiskPressure-False trap](#the-trap)
- [Longhorn: reading provider health](#longhorn-crds)
- [The snapshot-bloat pattern](#snapshot-bloat)
- [Seeing what eats a data disk without SSH](#du-without-ssh)
- [Longhorn: bounding snapshots so it does not recur](#bounding-snapshots)
- [Snapshots are not backups: verifying backup health](#backups)
- [Ceph / other CSI: where to look](#other-csi)

<a id="the-trap"></a>
## The disk-full-but-DiskPressure-False trap

The kubelet's `DiskPressure` condition watches only its own root/ephemeral
filesystem. A storage provider keeps volume data on a separate disk (often a
dedicated mount like `/mnt/data` or `/var/lib/longhorn`). That disk can be 100% full
while the node reports `DiskPressure = False`, because the kubelet is not looking at
it. Symptoms: writes failing inside pods, volumes that will not attach, the provider
refusing to schedule new replicas — all while node conditions look clean. Always
check the provider's own view of disk space, not just the node condition.

<a id="longhorn-crds"></a>
## Longhorn: reading provider health

Longhorn models everything as CRDs in `longhorn-system`. The useful ones:

```bash
# Volume state + robustness (healthy / degraded / faulted) — the top-level signal
kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness,NODE:.status.currentNodeID'

# Per-node, per-disk free space and whether Longhorn will still schedule to it
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq -r '
  .items[] | .metadata.name as $n | .status.diskStatus | to_entries[]
  | "\($n) \(.key) avail=\(.value.storageAvailable) max=\(.value.storageMaximum) " +
    ( [.value.conditions[] | select(.type=="Schedulable") | .status + "/" + (.reason//"")] | join("") )'

# Replicas: where each volume's copies live and whether any failed
kubectl get replicas.longhorn.io -n longhorn-system \
  -o custom-columns='NAME:.metadata.name,NODE:.spec.nodeID,STATE:.status.currentState,FAILED:.spec.failedAt'

# Engine purge/rebuild progress (async operations you must wait out)
kubectl get engines.longhorn.io -n longhorn-system -o json | jq -r '
  .items[] | select(.spec.volumeName=="<vol>") | .status.purgeStatus'

# Orphaned replica directories Longhorn has detected on disk
kubectl get orphans.longhorn.io -n longhorn-system
```

A disk with `Schedulable = False / DiskPressure` means Longhorn has stopped placing
replicas there because free space dropped below its reserve (default: 25% of the
disk). Existing volumes keep working, but you have lost that node as a target for
new or rebuilt replicas — so redundancy headroom silently shrinks. If several nodes
hit this at once, a single node failure may leave nowhere to rebuild.

<a id="snapshot-bloat"></a>
## The snapshot-bloat pattern

A frequent cause of a full provider disk is snapshot accumulation, and it is easy to
misread. Longhorn's own reservation accounting (`storageScheduled`) counts only the
*nominal* volume size, so a disk can show far more *used* than *scheduled* — the gap
is snapshot data the reservation never counted.

The classic offender is a **high-churn workload on a daily snapshot schedule with no
effective retention**: a database or a Prometheus TSDB rewrites most of its data
daily, so each snapshot captures a large delta. Fourteen daily snapshots of a 15 GB
volume can occupy ~90 GB. And because a volume has a replica on several nodes, the
*same* bloat exists on each of them — so one runaway volume can fill three nodes at
once and look like three separate problems.

Confirm it by listing snapshots for the suspect volume and their sizes:

```bash
kubectl get snapshots.longhorn.io -n longhorn-system -o json | jq -r '
  .items[] | select(.spec.volume=="<vol>")
  | "\(.metadata.creationTimestamp) \(.metadata.name) size=\(.status.size)"' | sort
```

Repeated `02:01`-style timestamps are a recurring snapshot job; a chain fourteen
deep with only-growing sizes is the retention gap.

<a id="du-without-ssh"></a>
## Seeing what eats a data disk without SSH

When you cannot SSH to the node, inspect the filesystem from a pod that already
host-mounts it. Longhorn's `instance-manager` mounts the whole host at `/host`:

```bash
POD=$(kubectl get pods -n longhorn-system --field-selector spec.nodeName=<node> -o json \
  | jq -r '.items[] | select(.metadata.name|test("instance-manager")) | .metadata.name' | head -1)

kubectl exec "$POD" -n longhorn-system -- df -h /host/mnt/data
kubectl exec "$POD" -n longhorn-system -- sh -c 'du -sh /host/mnt/data/replicas/* | sort -rh | head'
```

Run globbing shell commands via `sh -c '...'` so the `*` expands *inside* the
container, not in your local shell. Any privileged pod with a host mount works —
`instance-manager` (`/host`), or a CNI/CSI DaemonSet pod — this is a general trick,
not Longhorn-specific. It is read-only inspection; nothing is modified.

<a id="bounding-snapshots"></a>
## Longhorn: bounding snapshots so it does not recur

Two per-volume caps prevent runaway accumulation. Both are enforced by an admission
webhook, so read rejection messages and re-read the field to confirm it stuck:

- **`spec.snapshotMaxCount`** — a plain integer; caps the *number* of snapshots.
  Longhorn deletes the oldest when the limit is exceeded. Independent of volume
  size, so it is the intuitive lever for "keep only N days".
- **`spec.snapshotMaxSize`** — passed as a **quoted string of bytes**, and must be
  **at least twice the volume size** (the webhook rejects anything smaller, and `0`
  means unset). Caps total snapshot *space*. Count alone does not bound size, so for
  a high-churn volume combine both.

```bash
kubectl patch volumes.longhorn.io <vol> -n longhorn-system --type=merge \
  -p '{"spec":{"snapshotMaxCount":3}}'
kubectl get volumes.longhorn.io <vol> -n longhorn-system \
  -o jsonpath='{.spec.snapshotMaxCount}{"\n"}'   # verify it landed
```

Deleting a snapshot (`kubectl delete snapshots.longhorn.io <name> -n longhorn-system`)
marks it removed and queues an async purge that *coalesces* the chain — safe for a
healthy volume, and the live data (the volume head) is untouched. Space is reclaimed
only after the purge finishes; watch `.status.purgeStatus` until `isPurging` is
false on every replica before declaring the disk recovered. Remember snapshots are
not backups — they live on the same cluster; durability needs a `BackupTarget` to
external storage.

<a id="backups"></a>
## Snapshots are not backups: verifying backup health

A snapshot lives on the same disks as the volume it copies — it protects against
"oops I deleted a row," not against losing the cluster or the storage. Durability
needs a **backup to external storage** (object storage, another site). And a backup
job that has been silently failing is worse than none, because it buys false
confidence. When durability matters, verify the backups actually run and complete —
do not assume.

The mechanism varies (Velero, a provider's own `BackupTarget`, CSI
`VolumeSnapshot` → external), but the checks are the same shape:

```bash
# Velero (common cross-provider backup tool)
kubectl get backups -n velero                    # phase: Completed vs PartiallyFailed/Failed
kubectl describe backup <name> -n velero         # errors, warnings, item counts
kubectl get schedules -n velero                  # is a schedule even defined + active?

# CSI snapshot path
kubectl get volumesnapshots -A                   # READYTOUSE true?
kubectl get volumesnapshotclass                  # class exists and points at the driver
```

- **Latest backup is stale or failing** — check the *most recent* backup's phase and
  age, not that backups exist at all. A schedule that last succeeded weeks ago is a
  failed backup system wearing a green badge.
- **`PartiallyFailed`** — some items backed up, some did not; the ones that failed
  are often exactly the stateful volumes you care about. Read the per-item errors.
- **Missing/mismatched snapshot class** — a `VolumeSnapshot` stuck not-ready usually
  means no `VolumeSnapshotClass` matches the CSI driver, or the external snapshotter
  sidecar is not running. This is a config gap, not data loss — but it means
  volume-level backups are silently not happening.

<a id="other-csi"></a>
## Ceph / other CSI: where to look

The principle generalises: the provider's health is in its own resources, not core
Kubernetes objects.

- **Rook/Ceph** — `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status`
  and `ceph osd df` for per-OSD fullness; a `nearfull`/`full` OSD is the storage
  equivalent of the DiskPressure trap. `CephCluster`/`CephBlockPool` CRDs and the
  operator log carry health detail.
- **Any CSI driver** — check the `csi-*` controller and node DaemonSet pods in the
  provider's namespace, and the `VolumeAttachment` objects
  (`kubectl get volumeattachment`) for stuck attach/detach. `FailedMount` on a bound
  PVC is usually a node-level attachment or driver problem, not a scheduling one.
