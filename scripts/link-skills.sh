#!/usr/bin/env bash
#
# Symlink every skill in this repository into ~/.claude/skills so Claude Code
# reads them straight from source. Edits to SKILL.md then take effect live,
# without a build.
#
#   ./scripts/link-skills.sh            link all skills
#   ./scripts/link-skills.sh --unlink   remove the links again
#
set -euo pipefail


REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-./.claude/skills}"
UNLINK=false

[[ "${1:-}" == "--unlink" ]] && UNLINK=true

created_dir=false
if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
    created_dir=true
fi

count=0
# Each module contributes skills/<skill-name>/SKILL.md
while IFS= read -r skill_md; do
    skill_dir="$(dirname "$skill_md")"
    skill_name="$(basename "$skill_dir")"
    link="$TARGET_DIR/$skill_name"

    if $UNLINK; then
        if [[ -L "$link" ]]; then
            rm "$link"
            echo "unlinked  $skill_name"
            count=$((count + 1))
        fi
        continue
    fi

    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "SKIP      $skill_name — $link exists and is not a symlink" >&2
        continue
    fi

    ln -sfn "$skill_dir" "$link"
    echo "linked    $skill_name -> $skill_dir"
    count=$((count + 1))
done < <(find "$REPO_ROOT" -path "$REPO_ROOT/_template" -prune -o \
             -path '*/skills/*/SKILL.md' -print | sort)

if [[ $count -eq 0 ]]; then
    echo "No skills found." >&2
    exit 1
fi

echo
if $UNLINK; then
    echo "Removed $count link(s) from $TARGET_DIR"
else
    echo "Linked $count skill(s) into $TARGET_DIR"
    echo "Verify in Claude Code with: What skills are available?"
    if $created_dir; then
        echo
        echo "NOTE: $TARGET_DIR did not exist before now."
        echo "Restart Claude Code once so the directory gets watched."
    fi
fi
