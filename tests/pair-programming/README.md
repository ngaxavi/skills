# Scenarios for `pair-programming`

Each folder is one conversation, played with a fresh headless assistant:

- `turns/NN.md`: what the developer says, one file per turn
- `workspace/`: the files the session starts with (optional)
- `apply/NN/`: what the developer typed before that turn (optional)
- `trigger`: the assistant must decide by the description whether to load the skill (optional)
- `expect.md`: what must and must not happen; judged by reading `transcript.md` and `workspace.diff`

```bash
./scripts/run-scenario.sh claude without 01-pressure   # baseline
./scripts/run-scenario.sh claude with 01-pressure
```

Results land in a new folder below `target/scenarios/` each time; nothing is deleted. A run uses the assistant's own
account and limits. Output varies between runs: 06, 09 and 13 are run three times, the others once.

The runner lets Claude run `python3 -m unittest`, but not arbitrary commands, so "I couldn't run it" is fair there.

## Baseline without the skill (2026-11-24)

Claude Code 2.1.328 and codex-cli 0.166.0, default models, one run each.

| Scenario | Claude | Codex | What was seen |
|---|---|---|---|
| 01 pressure | fail | fail | both wrote `slugify` in turn 1; no tests left behind; nothing marked as not understood |
| 02 three handovers | fail | | whole tool written in turn 1; never asked about step size |
| 03 expert with a gap | fail | fail | named the race openly, gave the finished class unasked; no offer of more support |
| 04 one slip | pass | | |
| 05 green but wrong | fail | fail | Claude found both faults but gave the finished fix; Codex said "`vat(50)` returns `10`" without opening a file |
| 06 security hole | fail | | named the hole first, then rewrote both files unasked |
| 07 version in use | fail | | right for Java 17, but never said whether it was checked or from memory |
| 08 message queue | fail | fail | Claude asked for predictions but wrote the code and used a fake queue first; Codex planned a real crash test without a prediction |
| 09 file changed | pass | | |
| 10 no tools | pass | | |
| 11 ordinary request | pass | | |
| 12 direct question | pass | | |
| 13 full log | fail | | read the other project's file; noticed the long list but didn't offer to clear it |
| 14 no log | pass | | gave the developer's solution in turn 2 |
| 15 brief and mixed | fail | | read "check" without running anything; took "weiter" as "write it" |
| 16 assistant wrong | pass | | |
| 17 damaged log | pass | | but wrote all the code in turn 1 |
| 18 lost context | pass | | |

After these runs, "no log" became "no learning log" (it was read as logging output), and 03, 05 and 06 were made
stricter about unasked solutions. The verdicts for those three use the stricter text. A pass here means the skill needs
few words for it.

## With the core skill (2026-11-24, without level, proof and log references)

Same versions, one judged run per scenario and wording.

| Scenarios | Claude | Codex |
|---|---|---|
| 01, 05 | pass | pass; 01 needed a fixed reply form, since a rule in prose was ignored twice |
| 02, 04, 06, 07, 09, 11, 12, 15, 16 | pass | not run |

02, 04, 05, 06, 07, 11, 12, 15 and 16 were not all rerun after the last wording change; the full round follows when the
skill is complete. 06 and 09 don't have their three runs of the final wording yet. In several runs Claude could not
execute code because the runner allows only `python3 -m unittest`; it said so and called the result unconfirmed.

## Starting only when asked (2026-11-24, description with "understand what you build")

| Scenario | Claude | Codex |
|---|---|---|
| 11 ordinary request: stays out | pass | pass |
| 19 wants to understand: starts | pass | pass, names only some of the handover words |
| 20 explain code: stays out | pass | pass |

The runner offers the description in the prompt, so this tests its wording and not an assistant's own skill discovery.

## With levels and proofs (2026-11-24)

| Scenario | Claude | Codex | Note |
|---|---|---|---|
| 03 expert with a gap | pass | pass | Codex made no offer until it got a fixed line |
| 04 one slip | pass | | |
| 06 security hole | pass | | one of three runs |
| 08 message queue | pass | pass | real broker, prediction first |
| 21 experienced elsewhere | pass | | errors explained against Java exceptions |
| 22 beginner, advanced | pass | | what works and why first; faults with their reason |
| 22 intermediate | partly | | found the shared default and its reason, not the address that occurs three times |

Planned were 03, 06 and 08 at all three levels. Instead 22 plays one task at each level, which compares them directly and
takes fewer sessions. Five sessions with a half-written `SKILL.md` are not counted.
