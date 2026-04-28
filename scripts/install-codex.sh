#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-$PWD}"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/kewkie/bdr2-plugin/main}"
CONFIG_PATH="$TARGET_DIR/.codex/config.toml"
AGENTS_PATH="$TARGET_DIR/AGENTS.md"
BEGIN_MARKER="# >>> bdr2-plugin >>>"
END_MARKER="# <<< bdr2-plugin <<<"

mkdir -p "$TARGET_DIR/.codex"
touch "$CONFIG_PATH"

if rg -q '^\[mcp_servers\.bdr2\]' "$CONFIG_PATH"; then
  echo "bdr2 MCP server already present in $CONFIG_PATH"
else
  if [ -s "$CONFIG_PATH" ]; then
    printf "\n" >> "$CONFIG_PATH"
  fi
  cat >> "$CONFIG_PATH" <<'EOF'
[mcp_servers.bdr2]
url = "https://app.bdr2.com/api/mcp/"
EOF
  echo "Added bdr2 MCP server to $CONFIG_PATH"
fi

tmp_agents="$(mktemp)"
cleanup() {
  rm -f "$tmp_agents"
}
trap cleanup EXIT

curl -fsSL "$REPO_RAW_BASE/AGENTS.md" > "$tmp_agents"

if [ -f "$AGENTS_PATH" ] && rg -q '^# >>> bdr2-plugin >>>$' "$AGENTS_PATH" && rg -q '^# <<< bdr2-plugin <<<$' "$AGENTS_PATH"; then
  tmp_out="$(mktemp)"
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v replacement="$tmp_agents" '
    $0 == begin {
      print $0
      while ((getline line < replacement) > 0) print line
      close(replacement)
      skip=1
      next
    }
    $0 == end { skip=0; print $0; next }
    skip != 1 { print $0 }
  ' "$AGENTS_PATH" > "$tmp_out"
  mv "$tmp_out" "$AGENTS_PATH"
  echo "Updated existing bdr2 section in $AGENTS_PATH"
else
  if [ -s "$AGENTS_PATH" ]; then
    printf "\n\n" >> "$AGENTS_PATH"
  fi
  {
    echo "$BEGIN_MARKER"
    cat "$tmp_agents"
    echo "$END_MARKER"
  } >> "$AGENTS_PATH"
  echo "Appended bdr2 guidance to $AGENTS_PATH"
fi

echo "Done. Restart Codex (or open a new session) in $TARGET_DIR."
