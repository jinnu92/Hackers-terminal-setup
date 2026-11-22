# tests/helpers.bash — shared setup for the bats suite.
#
# Every test runs with HOME, XDG_STATE_HOME, XDG_CONFIG_HOME and TMPDIR pointing
# into a fresh temp directory, and with a stub directory first on PATH so no
# package manager or network command can run for real. Stubs log every call to
# $STUB_LOG; a test that expects "no work" asserts that file does not exist.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
TEST_BASH="${TEST_BASH:-bash}"
export REPO_ROOT

# Commands that must never run for real inside the suite.
STUBBED_COMMANDS="brew apt-get dnf yum pacman zypper sudo curl git npm npx pipx go cargo docker chsh uvx"

# Abort the test if HOME is not strictly inside the temp root.
assert_home_safe() {
  [ -n "${TEST_ROOT:-}" ] || { echo "TEST_ROOT unset" >&2; return 1; }
  case "$HOME" in
    "$TEST_ROOT"/?*) ;;
    *) echo "REFUSING: HOME ($HOME) is not under $TEST_ROOT" >&2; return 1 ;;
  esac
  case "$XDG_STATE_HOME" in "$TEST_ROOT"/?*) ;; *) echo "REFUSING: XDG_STATE_HOME" >&2; return 1 ;; esac
  case "$XDG_CONFIG_HOME" in "$TEST_ROOT"/?*) ;; *) echo "REFUSING: XDG_CONFIG_HOME" >&2; return 1 ;; esac
}

setup_env() {
  local base="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
  TEST_ROOT="$(mktemp -d "$base/hts-test.XXXXXX")"
  TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
  export TEST_ROOT
  export HOME="$TEST_ROOT/home"
  export XDG_STATE_HOME="$TEST_ROOT/state"
  export XDG_CONFIG_HOME="$TEST_ROOT/config"
  export TMPDIR="$TEST_ROOT/tmp"
  mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" "$TMPDIR"
  assert_home_safe || exit 1

  STUB_DIR="$TEST_ROOT/stubs"
  STUB_LOG="$TEST_ROOT/stub.log"
  export STUB_DIR STUB_LOG
  mkdir -p "$STUB_DIR"
  make_stubs
  export PATH="$STUB_DIR:$PATH"
  # Run from the temp root, never from the repo
  cd "$TEST_ROOT"
}

teardown_env() {
  case "${TEST_ROOT:-}" in
    */hts-test.??????) chmod -R u+rwX "$TEST_ROOT" 2>/dev/null; rm -rf "$TEST_ROOT" ;;
  esac
}

make_stubs() {
  local c
  for c in $STUBBED_COMMANDS; do
    [ "$c" = curl ] && continue
    printf '#!/bin/sh\necho "%s $*" >> "$STUB_LOG"\nexit 0\n' "$c" > "$STUB_DIR/$c"
    chmod +x "$STUB_DIR/$c"
  done
  # curl stub: serves file:// URLs only (copy), logs and fails for anything else.
  cat > "$STUB_DIR/curl" <<'STUB'
#!/bin/sh
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    --retry|--retry-delay|--connect-timeout|--max-time|-H|-w) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$url" in
  file://*)
    src="${url#file://}"
    [ -f "$src" ] || exit 37
    if [ -n "$out" ]; then cp "$src" "$out" || exit 23; else cat "$src"; fi
    exit 0 ;;
esac
echo "curl (blocked non-file URL) $url" >> "$STUB_LOG"
exit 7
STUB
  chmod +x "$STUB_DIR/curl"
}

# Run a bash snippet with the common helpers loaded. Exit status and output are
# those of the snippet. HTS_RUN_TS can be set by the snippet after sourcing.
hts_sh() {
  assert_home_safe || return 1
  "$TEST_BASH" -c 'set -e; cd "$TEST_ROOT"; . "$1/lib/common.sh"; shift; eval "$1"' _ "$REPO_ROOT" "$1"
}

# Run the installer (from the repo's ter.sh) with the given args, stdin closed.
run_ter() {
  assert_home_safe || return 1
  run "$TEST_BASH" "$REPO_ROOT/ter.sh" "$@" < /dev/null
}

# Assert no stub was invoked.
assert_no_stub_calls() {
  if [ -e "$STUB_LOG" ]; then
    echo "stubbed commands were called:" >&2; cat "$STUB_LOG" >&2; return 1
  fi
}

# Assert HOME and the XDG dirs are empty (nothing was created).
assert_home_untouched() {
  local n
  n="$(find "$HOME" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$n" != "0" ]; then
    echo "files were created under HOME/XDG dirs:" >&2
    find "$HOME" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" -mindepth 1 >&2
    return 1
  fi
}

file_mode() {   # mode string such as -rw-------
  ls -ld "$1" | awk '{print substr($1,1,10)}'
}

# Append a raw manifest row: kind name [detail]
manifest_row() {
  mkdir -p "$XDG_STATE_HOME/hts"
  printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$1" "$2" "${3:-}" >> "$XDG_STATE_HOME/hts/manifest.tsv"
}
