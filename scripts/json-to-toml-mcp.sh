#!/bin/bash
set -e

# Converts merged MCP server JSON to Codex TOML format.
# Input: JSON on stdin (merged base + profile MCP servers)
# Output: TOML [mcp_servers.*] sections on stdout
#
# Every string goes through jq's @json rather than manual quote concatenation.
# TOML basic strings use JSON's escape rules, so @json is the correct encoder for
# command, args, url, and env values. A server whose args contain embedded double
# quotes — any launcher that passes a shell snippet — otherwise emits a
# config.toml Codex cannot parse ("missing comma between array elements"), and an
# unparseable config takes the whole CLI down, not just that one server.
#
# Absent args default to []; an env table is emitted only when present.

jq -r '
to_entries[] |
if .value.type == "http" or (.value.url // "" | length > 0) then
  "[mcp_servers.\(.key)]",
  "type = \"http\"",
  "url = \(.value.url | @json)",
  ""
else
  "[mcp_servers.\(.key)]",
  "type = \"stdio\"",
  "command = \(.value.command | @json)",
  "args = [\((.value.args // []) | map(@json) | join(", "))]",
  (if (.value.env // {}) | length > 0 then
     "env = { \((.value.env | to_entries | map("\(.key) = \(.value | @json)") | join(", "))) }"
   else empty end),
  ""
end
'
