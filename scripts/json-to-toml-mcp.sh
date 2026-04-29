#!/bin/bash
set -e

# Converts merged MCP server JSON to Codex TOML format.
# Input: JSON on stdin (merged base + profile MCP servers)
# Output: TOML [mcp_servers.*] sections on stdout

jq -r '
to_entries[] |
if .value.type == "http" or (.value.url // "" | length > 0) then
  "[mcp_servers.\(.key)]",
  "type = \"http\"",
  "url = \"\(.value.url)\"",
  ""
else
  "[mcp_servers.\(.key)]",
  "type = \"stdio\"",
  "command = \"\(.value.command)\"",
  "args = [\(.value.args | map("\"" + . + "\"") | join(", "))]",
  ""
end
'
