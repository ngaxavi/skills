# agent-skills

Domain-specific [Agent Skills](https://agentskills.io/specification) packaged as a
Maven artifact, for use with JVM AI agents (Spring AI, LangChain4j) and file-based
code assistants (Claude Code, Cursor, Codex) via [SkillsJars](https://www.skillsjars.com/).

## Skills

| Skill | Purpose |
|---|---|
| `kubernetes-troubleshooting` | Systematic triage of Kubernetes workloads with `kubectl` — pods, PVCs, networking, nodes, and CSI storage providers. Covers failing workloads and proactive "is the cluster OK?" checks (restart-count and disk-headroom reading). Observe-before-you-act ordering. |

## Layout

```
skills/
└── kubernetes-troubleshooting/
    ├── SKILL.md                     # trigger + triage decision layer (<= 500 lines)
    └── references/
        ├── pod-states.md            # phases, container states, exit codes
        ├── kubectl-cheatsheet.md    # inspection commands, read-only vs mutating
        ├── storage-provider-troubleshooting.md  # CSI provider CRDs (Longhorn/Ceph), disk-full, snapshot bloat, backups
        ├── gitops-secrets-and-drift.md          # GitOps sync/drift, operator-synced secrets, credential drift
        ├── cluster-wide-events.md               # node reboot / service restart behind many pods restarting
        └── agent-integration.md                 # driving the skill from an autonomous agent (RBAC, risk tiers)
scripts/
├── link-skills.sh                  # symlink skills into .claude/skills for live local editing
└── check-skill-size.sh             # enforce the SKILL.md line budget (run by `mvn verify`)
```

Each skill is packaged into `META-INF/skills/<org>/<repo>/<skill>/` inside the JAR.

`SKILL.md` is the triage **decision layer** and stays lean — its whole body loads
into the model's context on every trigger, so depth lives in `references/` (loaded on
demand). `mvn verify` fails the build if any `SKILL.md` exceeds 500 lines; raising
the budget is a deliberate edit to `scripts/check-skill-size.sh`.

## Build

```bash
mvn verify                     # package + enforce the SKILL.md line budget
jar tf target/*.jar | grep SKILL.md
```

## Use it locally (before publishing)

```bash
mvn install
```

Then depend on it from another project at `1.0.0-SNAPSHOT`.

### Spring AI / custom JVM agent (classpath, no extraction)

```xml
<dependency>
  <groupId>org.springaicommunity</groupId>
  <artifactId>spring-ai-agent-utils</artifactId>
  <version>0.5.0</version>
</dependency>
<dependency>
  <groupId>com.github.ngaxavi.skills</groupId>
  <artifactId>ngaxavi-agent-skills</artifactId>
  <version>1.0.0-SNAPSHOT</version>
</dependency>
```

```properties
agent.skills.paths=classpath:/META-INF/skills
```

### File-based assistant (extraction)

Add the dependency under the SkillsJars plugin, then:

```bash
./mvnw skillsjars:extract -Ddir=.claude/skills
```

Put that command in your `AGENTS.md` so the agent runs it before working, and add
the extraction directory to `.gitignore` — it is build output.

## Publishing

`allowed-tools` in each `SKILL.md` frontmatter must match the corresponding
`skillsjars.skill.<name>.allowed-tools` property in `pom.xml`; the build fails on
mismatch. Once building cleanly, push to a public GitHub repo and submit via the
form on skillsjars.com.

## A note on trust

A skill is executable instruction delivered through a dependency resolver. Read any
third-party skill before trusting it, and treat these the same way — the source is
here, in plain Markdown, on purpose.

