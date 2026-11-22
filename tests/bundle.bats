#!/usr/bin/env bats
# The generated ter.sh must match the bundler output and survive piped execution.
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

@test "ter.sh is identical to a fresh ./bundle.sh output" {
  mkdir -p "$TEST_ROOT/copy"
  cp -R "$REPO_ROOT/lib" "$REPO_ROOT/bundle.sh" "$TEST_ROOT/copy/"
  cp "$REPO_ROOT/ter.sh" "$TEST_ROOT/copy/ter.committed"
  run "$TEST_BASH" "$TEST_ROOT/copy/bundle.sh"
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/copy/ter.sh" ]
  cmp "$TEST_ROOT/copy/ter.sh" "$REPO_ROOT/ter.sh" || {
    echo "ter.sh is out of date: run ./bundle.sh and commit the result" >&2
    return 1
  }
}

@test "ter.sh passes bash -n" {
  run "$TEST_BASH" -n "$REPO_ROOT/ter.sh"
  [ "$status" -eq 0 ]
}

@test "every lib/*.sh and bundle.sh passes bash -n" {
  local f
  for f in "$REPO_ROOT"/lib/*.sh "$REPO_ROOT/bundle.sh"; do
    "$TEST_BASH" -n "$f" || { echo "syntax error in $f" >&2; return 1; }
  done
}

@test "ter.sh is executable and has a bash shebang" {
  [ -x "$REPO_ROOT/ter.sh" ]
  [ "$(head -n 1 "$REPO_ROOT/ter.sh")" = "#!/usr/bin/env bash" ]
}

@test "piped execution ignores a decoy lib/ in the current directory" {
  mkdir -p "$TEST_ROOT/decoy/lib"
  local m
  for m in common versions pkg_mgr helpers preflight fonts dev terminals shell_tools ad_pivoting \
           web_api cloud_devsec mobile_re pentest bugbounty cloud ai_mcp workflow dashboard \
           doctor configs lifecycle menu hts_cli doctor_hygiene; do
    printf 'touch "%s/decoy-marker"\n' "$TEST_ROOT" > "$TEST_ROOT/decoy/lib/$m.sh"
  done
  cd "$TEST_ROOT/decoy"
  run "$TEST_BASH" -s -- --version < "$REPO_ROOT/ter.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+ ]]
  [ ! -e "$TEST_ROOT/decoy-marker" ]
}

@test "piped execution: --list and --dry-run --all work and create nothing" {
  mkdir -p "$TEST_ROOT/decoy/lib"
  printf 'touch "%s/decoy-marker"\n' "$TEST_ROOT" > "$TEST_ROOT/decoy/lib/common.sh"
  cd "$TEST_ROOT/decoy"
  run "$TEST_BASH" -s -- --list < "$REPO_ROOT/ter.sh"
  [ "$status" -eq 0 ]
  run "$TEST_BASH" -s -- --dry-run --all < "$REPO_ROOT/ter.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_ROOT/decoy-marker" ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "piped execution: unknown flag still exits 2" {
  run "$TEST_BASH" -s -- --nonsense < "$REPO_ROOT/ter.sh"
  [ "$status" -eq 2 ]
  assert_home_untouched
}
