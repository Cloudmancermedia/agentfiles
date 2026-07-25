#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=$1
OUTPUT=${2:-~/.codex/AGENTS.md}

title_from_filename() {
    local filename
    filename=$(basename "$1" .md)
    echo "$filename" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

skill_title() {
    local skill_file=$1
    local title
    title=$(awk '
        NR == 1 && $0 == "---" { in_frontmatter = 1; next }
        in_frontmatter && $0 == "---" { in_frontmatter = 0; next }
        in_frontmatter { next }
        /^# / {
            sub(/^# /, "")
            print
            exit
        }
    ' "$skill_file")

    if [[ -n "$title" ]]; then
        echo "$title"
    else
        basename "$(dirname "$skill_file")" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
    fi
}

frontmatter_value() {
    local skill_file=$1
    local key=$2
    awk -v key="$key" '
        NR == 1 && $0 == "---" { in_frontmatter = 1; next }
        in_frontmatter && $0 == "---" { exit }
        in_frontmatter && index($0, key ":") == 1 {
            sub("^" key ":[[:space:]]*", "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$skill_file"
}

stage_rules() {
    local source_dir=$1
    local target_dir=$2

    if [[ -d "$source_dir" ]]; then
        cp "$source_dir/"*.md "$target_dir/" 2>/dev/null || true
    fi
}

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile> [output-path]"
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

EFFECTIVE_RULES_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$EFFECTIVE_RULES_DIR"
}
trap cleanup EXIT

# Mirror deploy-rules.sh: base rules first, Claude-authored rules next, then
# profile rules last so matching filenames override earlier files.
stage_rules "$SCRIPT_DIR/base/rules" "$EFFECTIVE_RULES_DIR"
stage_rules "$SCRIPT_DIR/claude/rules" "$EFFECTIVE_RULES_DIR"
stage_rules "$SCRIPT_DIR/profiles/$PROFILE/rules" "$EFFECTIVE_RULES_DIR"

{
    # 1. Codex-specific preamble
    if [[ -f "$SCRIPT_DIR/codex/instructions.md" ]]; then
        cat "$SCRIPT_DIR/codex/instructions.md"
        echo ""
        echo "---"
        echo ""
    fi

    # 2. Shared behavioral instructions
    if [[ -f "$SCRIPT_DIR/base/CLAUDE.md" ]]; then
        echo "# Shared Instructions"
        echo ""
        cat "$SCRIPT_DIR/base/CLAUDE.md"
        echo ""
        echo "---"
        echo ""
    fi

    # 3. Profile-specific shared instructions (CLAUDE.md.append)
    if [[ -f "$SCRIPT_DIR/profiles/$PROFILE/CLAUDE.md.append" ]]; then
        SHARED_CONTENT=$(cat "$SCRIPT_DIR/profiles/$PROFILE/CLAUDE.md.append")
        if [[ -n "$SHARED_CONTENT" ]]; then
            echo "# Profile Instructions"
            echo ""
            echo "$SHARED_CONTENT"
            echo ""
            echo "---"
            echo ""
        fi
    fi

    # 4. Effective rules. Each file becomes a section after applying the same
    #    override order as Claude Code's rules directory deployment.
    for rule in "$EFFECTIVE_RULES_DIR/"*.md; do
        [[ -f "$rule" ]] || continue
        title=$(title_from_filename "$rule")
        echo "## $title"
        echo ""
        cat "$rule"
        echo ""
        echo "---"
        echo ""
    done

    # 5. Custom skill index. Skill bodies are installed into ~/.codex/skills by
    #    deploy-skills.sh, matching Claude Code's on-demand skill loading model.
    #    AGENTS.md only carries lightweight trigger metadata.
    #    Index only the profile's allowlist (profile-skills.sh), so a skill
    #    outside the profile is neither installed nor advertised.
    if [[ -d "$SCRIPT_DIR/claude/skills" ]]; then
        found_skill=false
        while IFS= read -r skill_name; do
            [[ -n "$skill_name" ]] || continue
            skill="$SCRIPT_DIR/claude/skills/$skill_name/SKILL.md"
            [[ -f "$skill" ]] || continue
            if [[ "$found_skill" == false ]]; then
                echo "# Custom Skills"
                echo ""
                echo "The following custom skills are installed into \`~/.codex/skills\`. Use a skill when its trigger description matches the task, and load the skill body from the installed skill instead of relying on an inlined copy in this file."
                echo ""
                found_skill=true
            fi

            name=$(frontmatter_value "$skill" name)
            description=$(frontmatter_value "$skill" description)
            if [[ -z "$name" ]]; then
                name=$(basename "$(dirname "$skill")")
            fi
            if [[ -z "$description" ]]; then
                description="See $(skill_title "$skill") for usage guidance."
            fi
            echo "- \`$name\`: $description"
        done < <("$SCRIPT_DIR/scripts/profile-skills.sh" "$PROFILE")
        if [[ "$found_skill" == true ]]; then
            echo ""
            echo "---"
            echo ""
        fi
    fi

    # 6. Codex-specific additions that are not generated elsewhere.
    if [[ -f "$SCRIPT_DIR/profiles/$PROFILE/AGENTS.md.append" ]]; then
        APPEND_CONTENT=$(cat "$SCRIPT_DIR/profiles/$PROFILE/AGENTS.md.append")
        if [[ -n "$APPEND_CONTENT" ]]; then
            echo "$APPEND_CONTENT"
            echo ""
        fi
    fi
} > "$OUTPUT"

echo "  -> $OUTPUT compiled"
