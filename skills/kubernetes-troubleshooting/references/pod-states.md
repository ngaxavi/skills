# Reference: Pod States and Exit Codes

## Pod phases

The pod `phase` is a coarse, top-level summary. Do not diagnose from the phase
alone — the container states below are where the detail is.

| Phase | Meaning |
|---|---|
| `Pending` | Accepted by the cluster, but one or more containers are not yet running. Usually scheduling or image pull. |
| `Running` | Bound to a node, at least one container running. Says nothing about whether the app is healthy — only that it started. |
| `Succeeded` | All containers terminated with success and will not restart. Normal for Jobs. |
| `Failed` | All containers terminated, at least one with failure. |
| `Unknown` | The pod's state cannot be obtained, typically because the node is unreachable. |

## Container states

Each container is in one of three states. `kubectl describe pod` shows the current
state and the last terminated state.

- **Waiting** — not yet running. The `reason` is the useful part:
  `ContainerCreating`, `ImagePullBackOff`, `ErrImagePull`, `CrashLoopBackOff`,
  `CreateContainerConfigError` (missing configmap/secret referenced by env or
  volume).
- **Running** — started and not yet terminated. Has a start time.
- **Terminated** — ran and stopped. Carries an `exitCode`, `reason`, and
  `finishedAt`. This is what `--previous` logs correspond to.

## Reason strings worth recognizing

| Reason | What it actually means |
|---|---|
| `ContainerCreating` | kubelet is setting up the container: pulling image, mounting volumes, wiring network. Stuck here → volume or image or CNI. |
| `CreateContainerConfigError` | A referenced ConfigMap or Secret does not exist, or a key is missing. |
| `CrashLoopBackOff` | Container repeatedly starts and exits; kubelet is backing off between restarts. The error is in the previous instance's logs. |
| `ImagePullBackOff` / `ErrImagePull` | Image could not be pulled: wrong name/tag, auth, or registry unreachable. |
| `RunContainerError` | The container failed to start at the runtime level (bad command, permission, mount). |
| `OOMKilled` | Killed for exceeding its memory limit. Appears as the termination reason with exit code 137. |

## Exit codes worth memorizing

| Exit code | Meaning |
|---|---|
| `0` | Clean exit. Unexpected for a long-running service — suggests the process completed and left. |
| `1` | Generic application error. Read the logs / stack trace. |
| `137` | `128 + 9` (SIGKILL). Almost always OOMKilled, or a forced termination. |
| `139` | `128 + 11` (SIGSEGV). Segmentation fault in the process. |
| `143` | `128 + 15` (SIGTERM). Graceful stop was requested; often a downstream effect, not the root cause. |
| `126` | Command found but not executable (permissions, wrong binary). |
| `127` | Command not found — wrong entrypoint/command, or missing binary in the image. |

The `128 + N` pattern: any exit code above 128 usually means the process was killed
by signal `N = code − 128`.

## Requests vs. limits (the distinction that trips people up)

- **Requests** are what the scheduler uses to place a pod. `Insufficient cpu/memory`
  at scheduling time is about requests exceeding node allocatable headroom.
- **Limits** are enforced at runtime. `OOMKilled` is about a container exceeding its
  memory limit.

A pod can schedule fine (requests satisfied) and still be OOMKilled later (limit
exceeded), and vice versa. When you read an error, know which of the two it concerns
before changing numbers.
