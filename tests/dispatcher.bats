#!/usr/bin/env bats
# Dispatcher behaviour through stable interfaces: flags, exit codes, side effects.
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

# Build a copy of ter.sh without its final "_hts_main" call, so a driver can
# source it, replace every install function with a marker writer, and then call
# _hts_main itself. Writes the driver to $TEST_ROOT/driver.sh.
make_driver() {
  sed '$d' "$REPO_ROOT/ter.sh" > "$TEST_ROOT/ter_nomain.sh"
  cat > "$TEST_ROOT/driver.sh" <<'DRV'
set +e
. "$TEST_ROOT/ter_nomain.sh"
set +e
_stub_fns="preflight_base ensure_omz ensure_ssh_dir ensure_pipx ensure_go"
for _id in $HTS_LIST_IDS; do
  hts_comp_info "$_id"
  _stub_fns="$_stub_fns ${HTS_C_CMD%% *}"
done
for _fn in $_stub_fns; do
  eval "$_fn() { echo $_fn >> \"\$TEST_ROOT/markers\"; return 0; }"
done
_hts_main "$@"
DRV
}

@test "--version prints the version and exits 0 without touching anything" {
  run_ter --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+ ]]
  want="$(sed -n 's/^HTS_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/lib/common.sh")"
  [[ "$output" == *"$want"* ]]
  assert_no_stub_calls
  assert_home_untouched
}

@test "-V is the same as --version" {
  run_ter -V
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+ ]]
}

@test "--list exits 0, lists core components, touches nothing" {
  run_ter --list
  [ "$status" -eq 0 ]
  for flag in --core --fonts --mcp --pentest --workflow --config --doctor; do
    [[ "$output" == *"$flag"* ]]
  done
  assert_no_stub_calls
  assert_home_untouched
}

@test "--help exits 0 and mentions the lifecycle flags" {
  run_ter --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--status"* ]]
  [[ "$output" == *"--uninstall"* ]]
  assert_home_untouched
}

@test "unknown flag exits 2 and performs no work" {
  run_ter --definitely-not-a-flag
  [ "$status" -eq 2 ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "unknown flag mixed with valid components exits 2 before any work" {
  run_ter --core --definitely-not-a-flag --fonts
  [ "$status" -eq 2 ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "unknown flag alongside --dry-run still exits 2" {
  run_ter --dry-run --bogus
  [ "$status" -eq 2 ]
  assert_no_stub_calls
}

@test "--dry-run --all exits 0, calls no stubbed command, creates nothing" {
  run_ter --dry-run --all
  [ "$status" -eq 0 ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "-n with numbers selects only those components" {
  run_ter -n 1 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"--core"* ]]
  [[ "$output" == *"--node"* ]]
  [[ "$output" != *"--pentest"* ]]
  assert_home_untouched
}

@test "dry-run with the doctor flag in any position exits 0 and runs nothing" {
  local args
  for args in "--dry-run --doctor" "--doctor --dry-run" "-d -n" "-n --core --doctor" "--doctor --json --dry-run" "--json --dry-run -d"; do
    # shellcheck disable=SC2086
    run_ter $args
    [ "$status" -eq 0 ] || { echo "failed for: $args" >&2; return 1; }
    assert_no_stub_calls
    assert_home_untouched
  done
}

@test "--dry-run --all calls no install function (driver with marker stubs)" {
  make_driver
  run "$TEST_BASH" "$TEST_ROOT/driver.sh" --dry-run --all < /dev/null
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_ROOT/markers" ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "dry-run of every individual component calls no install function" {
  make_driver
  local flag
  for flag in --core --fonts --node --claude --code --dev --terminals --shell-tools --mcp \
              --pentest --seclists --bugbounty --ad-pivot --web-api --cloud --mobile --ai \
              --workflow --dashboard --config --doctor; do
    run "$TEST_BASH" "$TEST_ROOT/driver.sh" --dry-run "$flag" < /dev/null
    [ "$status" -eq 0 ] || { echo "failed for $flag: $output" >&2; return 1; }
  done
  [ ! -e "$TEST_ROOT/markers" ]
  assert_home_untouched
}

@test "control: without --dry-run the driver's marker stubs DO get called" {
  make_driver
  run "$TEST_BASH" "$TEST_ROOT/driver.sh" -y --core < /dev/null
  [ -e "$TEST_ROOT/markers" ]
  grep -q install_core "$TEST_ROOT/markers"
  assert_home_safe
}

@test "lifecycle flags cannot be combined with components" {
  local args
  for args in "--status --core" "--core --status" "--uninstall --fonts" "--restore --core" \
              "--update --all" "--status --uninstall" "--purge-tools"; do
    # shellcheck disable=SC2086
    run_ter $args
    [ "$status" -eq 2 ] || { echo "expected exit 2 for: $args (got $status)" >&2; return 1; }
    assert_no_stub_calls
    assert_home_untouched
  done
}

@test "--purge-tools is rejected unless combined with --uninstall" {
  run_ter --status --purge-tools
  [ "$status" -eq 2 ]
}

@test "--status on a clean machine exits 0 and writes nothing under HOME" {
  run_ter --status
  [ "$status" -eq 0 ]
  assert_no_stub_calls
  assert_home_untouched
}

@test "piped stdin without a terminal and no menu input does not hang or install" {
  # No arguments and no tty: must not run an install silently from a closed stdin.
  run perl -e 'alarm 20; exec @ARGV' "$TEST_BASH" "$REPO_ROOT/ter.sh" --dry-run < /dev/null
  [ "$status" -eq 0 ]
  assert_home_untouched
}

# Doctor itself is audited by CI only (set HTS_TEST_RUN_DOCTOR=1): it inspects
# the machine, so it is skipped for local runs.
@test "doctor --json prints valid JSON in every flag position (CI only)" {
  [ "${HTS_TEST_RUN_DOCTOR:-0}" = "1" ] || skip "set HTS_TEST_RUN_DOCTOR=1 to run the doctor audit"
  command -v python3 >/dev/null || skip "python3 not available"
  local args
  for args in "--doctor --json" "--json --doctor" "-d --json" "--json -d -y"; do
    # shellcheck disable=SC2086
    "$TEST_BASH" "$REPO_ROOT/ter.sh" $args < /dev/null > "$TEST_ROOT/doctor.out" 2>/dev/null || true
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$TEST_ROOT/doctor.out" \
      || { echo "invalid JSON for: $args" >&2; head -c 500 "$TEST_ROOT/doctor.out" >&2; return 1; }
  done
}
