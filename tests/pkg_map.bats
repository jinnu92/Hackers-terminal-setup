#!/usr/bin/env bats
# resolve_pkg contract: for every tool and manager the result is either a
# non-empty package name with status 0, or status 3 (no package) — never an
# empty name with status 0.
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

# Tool names: every word in a case pattern of resolve_pkg, plus common names
# that fall through to the default branch.
tool_names() {
  awk '/^resolve_pkg\(\)/ {on=1} on && /^}/ {exit} on' "$REPO_ROOT/lib/pkg_mgr.sh" \
    | grep -E '^[[:space:]]+[A-Za-z0-9_|*.+-]+\)' \
    | sed -E 's/^[[:space:]]+//; s/\).*$//' \
    | tr '|' '\n' | grep -v '^\*$' | sort -u
  printf '%s\n' curl wget jq git tmux fzf bat ripgrep nmap python3 pipx unknown-tool-xyz
}

@test "tool table is not empty" {
  n="$(tool_names | wc -l | tr -d ' ')"
  [ "$n" -gt 30 ]
}

@test "resolve_pkg: every tool x every manager is a name (status 0) or status 3" {
  tool_names | sort -u > "$TEST_ROOT/tools.txt"
  export TOOLS_FILE="$TEST_ROOT/tools.txt"
  run hts_sh '
    . "$REPO_ROOT/lib/pkg_mgr.sh"
    bad=0; count=0
    for mgr in brew apt dnf yum pacman zypper; do
      PKG_MGR=$mgr
      while read -r tool; do
        [ -n "$tool" ] || continue
        rc=0; out="$(resolve_pkg "$tool" 2>/dev/null)" || rc=$?
        count=$((count + 1))
        if [ "$rc" -eq 0 ] && [ -z "$out" ]; then echo "EMPTY-WITH-STATUS-0: $mgr/$tool"; bad=1; fi
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then echo "BAD-STATUS $rc: $mgr/$tool"; bad=1; fi
        if [ "$rc" -eq 3 ] && [ -n "$out" ]; then echo "NAME-WITH-STATUS-3: $mgr/$tool=$out"; bad=1; fi
      done < "$TOOLS_FILE"
    done
    echo "checked $count combinations"
    exit $bad'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked "* ]]
}

@test "resolve_pkg: unmapped tools print nothing on stdout" {
  run hts_sh '. "$REPO_ROOT/lib/pkg_mgr.sh"; PKG_MGR=apt; rc=0; out="$(resolve_pkg trivy 2>/dev/null)" || rc=$?; [ "$rc" -eq 3 ] && [ -z "$out" ]'
  [ "$status" -eq 0 ]
}

@test "pkg_install: reports status 3 when the only tool has no package" {
  run hts_sh '. "$REPO_ROOT/lib/pkg_mgr.sh"; PKG_MGR=apt; rc=0; pkg_install trivy >/dev/null 2>&1 || rc=$?; exit $rc'
  [ "$status" -eq 3 ]
  assert_no_stub_calls
}
