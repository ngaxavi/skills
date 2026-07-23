#!/usr/bin/env bash
#
# Enforce the SKILL.md line budget. The whole SKILL.md body loads into the model's
# context every time the skill triggers, so a bloated spine costs tokens and dilutes
# the decision signal on every invocation. Keep the body as the triage decision layer
# and push depth into references/ (loaded on demand).
#
# Fails the build if any skills/*/SKILL.md exceeds MAX_LINES. Raising the budget is a
# deliberate one-line change here — not something that should happen by accident.
#
#   ./scripts/check-skill-size.sh           # check with the default budget
#   MAX_LINES=550 ./scripts/check-skill-size.sh
set -euo pipefail

MAX_LINES="${MAX_LINES:-500}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0
found=0
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    [[ -e "$f" ]] || continue
    found=1
    n=$(wc -l < "$f")
    rel="${f#"$REPO_ROOT"/}"
    if [[ "$n" -gt "$MAX_LINES" ]]; then
        echo "FAIL  $rel: $n lines > $MAX_LINES budget"
        fail=1
    else
        echo "ok    $rel: $n / $MAX_LINES lines"
    fi
done

if [[ "$found" -eq 0 ]]; then
    echo "no skills/*/SKILL.md found under $REPO_ROOT" >&2
    exit 1
fi

exit "$fail"
