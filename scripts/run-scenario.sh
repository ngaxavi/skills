#!/usr/bin/env bash
#
# Play one scenario from tests/<skill>/ with a fresh headless assistant. Each run gets its
# own new folder below target/scenarios/; this script never deletes anything.
# Personal instructions, skills and settings are off.
#
#   ./scripts/run-scenario.sh <claude|codex> <with|without> <scenario>
#   ./scripts/run-scenario.sh claude without 01-pressure
#
# Judge transcript.md and workspace.diff against the scenario's expect.md.
# SKILL (default pair-programming), MODEL and TURN_SECONDS (default 300) can be set.
set -euo pipefail

[[ $# -eq 3 ]] || { sed -n '3,11p' "$0" >&2; exit 2; }
agent=$1; mode=$2; scenario=$3
[[ $agent == claude || $agent == codex ]] || { echo "unknown assistant: $agent" >&2; exit 2; }
[[ $mode == with || $mode == without ]] || { echo "unknown mode: $mode" >&2; exit 2; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${SKILL:-pair-programming}"
TURN_SECONDS="${TURN_SECONDS:-300}"
src="$REPO_ROOT/tests/$SKILL/$scenario"
[[ -d $src/turns ]] || { echo "no such scenario: $src" >&2; exit 2; }

mkdir -p "$REPO_ROOT/target/scenarios"
out="$(mktemp -d "$REPO_ROOT/target/scenarios/$scenario.$agent.$mode.$(date +%Y%m%d-%H%M%S).XXXX")"
# Outside the repository, so that an assistant can't read expect.md next to it.
work="$(mktemp -d "${TMPDIR:-/tmp}/scenario.XXXXXX")"
mkdir -p "$work/ws/home"
[[ -d $src/workspace ]] && cp -R "$src/workspace/." "$work/ws/"
cp -R "$work/ws" "$work/before"
if [[ $mode == with ]]; then
    cp -R "$REPO_ROOT/skills/$SKILL" "$work/ws/$SKILL"
fi
git -C "$work/ws" init -q

intro="In this session ./home is the user's home folder, also for ~. Work only inside the current folder."
if [[ -f $src/trigger ]]; then
    if [[ $mode == with ]]; then
        description="$(awk '/^description:/{f=1} f&&/^(license:|---)/{exit} f' "$work/ws/$SKILL/SKILL.md")"
        intro+=$'\n'"Skills you may load by reading their SKILL.md, only if the description fits the request:"
        intro+=$'\n'"- ./$SKILL/SKILL.md $description"
    fi
elif [[ $mode == with ]]; then
    intro+=$'\n'"Read ./$SKILL/SKILL.md and follow it."
fi

# macOS has no timeout(1); perl's alarm survives exec.
limited() { perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$TURN_SECONDS" "$@"; }

session="$(uuidgen | tr '[:upper:]' '[:lower:]')"
n=0
for turn in "$src"/turns/*.md; do
    n=$((n + 1)); id="$(basename "$turn" .md)"
    # What the developer typed between two turns.
    [[ -d $src/apply/$id ]] && cp -R "$src/apply/$id/." "$work/ws/"
    text="$(cat "$turn")"
    prompt="$text"
    [[ $n -eq 1 ]] && prompt="$intro"$'\n\n'"$text"
    printf '\n## Developer (%s)\n\n%s\n\n## Assistant (%s)\n\n' "$id" "$text" "$id" >> "$out/transcript.md"
    status=0
    if [[ $agent == claude ]]; then
        args=(-p --safe-mode --permission-mode acceptEdits --output-format text
              --allowedTools "Read Edit Write Glob Grep Bash(python3 -m unittest:*) Bash(python3 -B -m unittest:*) Bash(ls:*) Bash(cat:*) WebFetch WebSearch")
        [[ -n ${MODEL:-} ]] && args+=(--model "$MODEL")
        if [[ $n -eq 1 ]]; then args+=(--session-id "$session"); else args+=(--resume "$session"); fi
        (cd "$work/ws" && limited claude "${args[@]}" <<< "$prompt") >> "$out/transcript.md" 2>> "$out/stderr.txt" || status=$?
    else
        args=(--skip-git-repo-check --ignore-user-config --json -o "$work/last.txt")
        [[ -n ${MODEL:-} ]] && args+=(-m "$MODEL")
        : > "$work/last.txt"
        if [[ $n -eq 1 ]]; then
            (cd "$work/ws" && limited codex exec -s workspace-write "${args[@]}" - <<< "$prompt") > "$work/events.jsonl" 2>> "$out/stderr.txt" || status=$?
            session="$(grep -m1 -oE '"thread_id":"[^"]+"' "$work/events.jsonl" | cut -d'"' -f4 || true)"
        else
            (cd "$work/ws" && limited codex exec resume "${args[@]}" -c sandbox_mode=workspace-write "$session" - <<< "$prompt") > "$work/events.jsonl" 2>> "$out/stderr.txt" || status=$?
        fi
        cat "$work/events.jsonl" >> "$out/events.jsonl"
        cat "$work/last.txt" >> "$out/transcript.md"
    fi
    if [[ $status -ne 0 ]]; then
        printf '\n[run failed or timed out, exit %s]\n' "$status" >> "$out/transcript.md"
        echo "FAILED at turn $id (exit $status): $out" >&2
        exit 1
    fi
done
(cd "$work" && diff -ruN -x .git -x "$SKILL" -x __pycache__ before ws) > "$out/workspace.diff" || true
echo "done: $out"
