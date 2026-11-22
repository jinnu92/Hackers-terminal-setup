#!/usr/bin/env bats
# Static checks on pinned versions and digests.
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

# Print "NAME=value" (quotes and trailing comments stripped) for assignments
# whose name matches the ERE given as $1 in the files after it.
assignments() {
  local re=$1; shift
  sed -nE "s/^[[:space:]]*($re)=[\"']?([^\"'#[:space:]]*)[\"']?.*/\1=\2/p" "$@"
}

@test "versions.sh: every *SHA256* value is 64 lowercase hex characters" {
  assignments '[A-Z0-9_]*SHA256[A-Z0-9_]*' "$REPO_ROOT/lib/versions.sh" > "$TEST_ROOT/shas.txt"
  [ "$(wc -l < "$TEST_ROOT/shas.txt" | tr -d ' ')" -gt 20 ]
  local line bad=0
  while IFS= read -r line; do
    if ! printf '%s' "${line#*=}" | grep -Eq '^[0-9a-f]{64}$'; then
      echo "bad digest: $line" >&2; bad=1
    fi
  done < "$TEST_ROOT/shas.txt"
  [ "$bad" -eq 0 ]
}

@test "ai_mcp.sh: every MCP_*_SHA_* value is 64 lowercase hex characters" {
  assignments 'MCP_[A-Z0-9_]*_SHA_[A-Z0-9_]*' "$REPO_ROOT/lib/ai_mcp.sh" > "$TEST_ROOT/shas.txt"
  [ "$(wc -l < "$TEST_ROOT/shas.txt" | tr -d ' ')" -ge 1 ]
  local line bad=0
  while IFS= read -r line; do
    printf '%s' "${line#*=}" | grep -Eq '^[0-9a-f]{64}$' || { echo "bad digest: $line" >&2; bad=1; }
  done < "$TEST_ROOT/shas.txt"
  [ "$bad" -eq 0 ]
}

@test "every *_VERSION pin in versions.sh and ai_mcp.sh is non-empty" {
  assignments '[A-Z0-9_]+_VERSION' "$REPO_ROOT/lib/versions.sh" "$REPO_ROOT/lib/ai_mcp.sh" > "$TEST_ROOT/vers.txt"
  [ "$(wc -l < "$TEST_ROOT/vers.txt" | tr -d ' ')" -gt 15 ]
  local line bad=0
  while IFS= read -r line; do
    [ -n "${line#*=}" ] || { echo "empty version: $line" >&2; bad=1; }
  done < "$TEST_ROOT/vers.txt"
  [ "$bad" -eq 0 ]
}

@test "every *_VERSION assignment line has a quoted non-empty value" {
  ! grep -Eq '^[[:space:]]*[A-Z0-9_]+_VERSION=(""|'"''"')?[[:space:]]*(#.*)?$' "$REPO_ROOT/lib/versions.sh" "$REPO_ROOT/lib/ai_mcp.sh"
}

@test "no digest value is duplicated across different tools by accident" {
  assignments '[A-Z0-9_]*SHA256[A-Z0-9_]*' "$REPO_ROOT/lib/versions.sh" | cut -d= -f2 | sort | uniq -d > "$TEST_ROOT/dups.txt"
  [ ! -s "$TEST_ROOT/dups.txt" ]
}
