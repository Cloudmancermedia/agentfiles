#!/bin/bash
set -euo pipefail

# MCP servers reach Codex's config.toml through this converter. A server whose
# args contain double quotes — any launcher that passes a shell snippet — used to
# emit unparseable TOML, and Codex refuses to start on a config it cannot parse.
# So a quoting bug here takes the whole CLI down, not one server.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; exit $rc' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

command -v python3 >/dev/null || { echo "SKIP: python3 unavailable (needed to parse TOML)"; exit 0; }

parses() {
  python3 - "$1" <<'PY'
import sys, tomllib
try:
    tomllib.load(open(sys.argv[1], "rb"))
except Exception as e:
    print(e); sys.exit(1)
PY
}

# --- Embedded quotes, backslashes, env, and an http server in one payload ----
cat > "$TMP_DIR/in.json" <<'JSON'
{
  "quoted": {
    "command": "bash",
    "args": ["-c", "R=\"$(ls -d /x/y-*/ | tail -n1)\"; exec \"$R/bin\" --flag=\"v\""]
  },
  "backslash": { "command": "sh", "args": ["-c", "printf 'a\\tb'"] },
  "noargs": { "command": "plain" },
  "withenv": { "command": "srv", "args": ["--go"], "env": { "TOKEN_NAME": "a\"b" } },
  "remote": { "type": "http", "url": "https://mcp.example.com/mcp" }
}
JSON

"$ROOT_DIR/scripts/json-to-toml-mcp.sh" < "$TMP_DIR/in.json" > "$TMP_DIR/out.toml"
parses "$TMP_DIR/out.toml" || fail "converter emitted TOML that does not parse"

python3 - "$TMP_DIR/in.json" "$TMP_DIR/out.toml" <<'PY' || exit 1
import json, sys, tomllib
src = json.load(open(sys.argv[1]))
got = tomllib.load(open(sys.argv[2], "rb"))["mcp_servers"]
for name, spec in src.items():
    if spec.get("type") == "http" or spec.get("url"):
        assert got[name]["url"] == spec["url"], f"{name}: url did not round-trip"
        continue
    assert got[name]["command"] == spec["command"], f"{name}: command did not round-trip"
    assert got[name].get("args", []) == spec.get("args", []), (
        f"{name}: args did not round-trip\n  want {spec.get('args', [])}\n  got  {got[name].get('args', [])}")
    assert got[name].get("env", {}) == spec.get("env", {}), (
        f"{name}: env did not round-trip\n  want {spec.get('env', {})}\n  got  {got[name].get('env', {})}")
print("round-trip ok:", ", ".join(sorted(src)))
PY

# --- Every shipped profile's MCP servers must convert cleanly ----------------
for mcp in "$ROOT_DIR"/base/mcp-servers-base.json "$ROOT_DIR"/profiles/*/mcp-servers.json; do
  [[ -f "$mcp" ]] || continue
  # Skip empty manifests ({} or no servers) — nothing to convert.
  [[ "$(jq -r 'length' "$mcp")" == "0" ]] && continue
  sed -e "s|{{HOME}}|$HOME|g" -e "s|{{CLAUDE_DIR}}|$HOME/.claude|g" "$mcp" \
    | "$ROOT_DIR/scripts/json-to-toml-mcp.sh" > "$TMP_DIR/shipped.toml"
  parses "$TMP_DIR/shipped.toml" || fail "$mcp produces unparseable TOML"
done

echo "PASS: MCP JSON converts to TOML that parses, with quotes, backslashes, and env intact"
