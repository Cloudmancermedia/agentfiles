#!/bin/bash
set -euo pipefail

# Example PreToolUse hook: deny reading .env files, so secrets in a project's
# environment file never enter the conversation.
#
# Not deployed as shipped (scripts/deploy-hooks.sh skips subdirectories). To use
# it, move it up to base/hooks/ (every profile) or profiles/<p>/hooks/ (one
# profile), then register it in that layer's settings.json:
#
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Read",
#         "hooks": [{ "type": "command",
#                     "command": "{{CLAUDE_DIR}}/hooks/block-env-reads.sh" }] }
#     ]
#   }
#
# Claude Code passes the tool call as JSON on stdin. Printing a
# permissionDecision of "deny" blocks the call and shows the reason to Claude;
# printing nothing lets it through. https://code.claude.com/docs/en/hooks

path=$(jq -r '.tool_input.file_path // empty')

case "$(basename "$path")" in
    .env|.env.*)
        jq -n --arg r "Reading $path is blocked: .env files hold secrets. Ask the user for the value you need." \
            '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
        ;;
esac
