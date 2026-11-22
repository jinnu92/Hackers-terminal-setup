#!/usr/bin/env bats
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

# ─── run_step / summary ───────────────────────────────────────────────────────
@test "run_step: success records ok and returns 0" {
  run hts_sh 'ok_fn() { echo hi; }; run_step "good" ok_fn; echo "rc=$?"; echo "${HTS_RES_STATUS[0]}:${HTS_RES_LABEL[0]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
  [[ "$output" == *"ok:good"* ]]
}

@test "run_step: failure returns the command status, records fail, does not abort" {
  run hts_sh 'bad_fn() { return 7; }; rc=0; run_step "bad" bad_fn || rc=$?; echo "rc=$rc"; echo "${HTS_RES_STATUS[0]}"; echo still-alive'
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=7"* ]]
  [[ "$output" == *"fail"* ]]
  [[ "$output" == *"still-alive"* ]]
}

@test "run_step: a failing step does not stop later steps" {
  run hts_sh '
    bad_fn() { return 1; }
    good_fn() { touch "$TEST_ROOT/second-ran"; }
    run_step "one" bad_fn || true
    run_step "two" good_fn
    echo "${HTS_RES_STATUS[0]},${HTS_RES_STATUS[1]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"fail,ok"* ]]
  [ -e "$TEST_ROOT/second-ran" ]
}

@test "run_step: errexit is restored after a step" {
  run hts_sh '
    inner() { false; return 0; }
    run_step "e" inner
    case "$-" in *e*) echo errexit-on ;; *) echo errexit-off ;; esac'
  [ "$status" -eq 0 ]
  [[ "$output" == *"errexit-on"* ]]
}

@test "run_step: output is written to the install log when the state dir exists" {
  run hts_sh 'hts_state_init; say() { echo "marker-line-xyz"; }; run_step "log" say; grep -q marker-line-xyz "$HTS_LOG" && echo logged'
  [ "$status" -eq 0 ]
  [[ "$output" == *"logged"* ]]
}

@test "hts_print_summary: exit 0 when nothing failed, 1 when any step failed" {
  run hts_sh 'hts_result ok a; hts_result skip b; hts_print_summary >/dev/null'
  [ "$status" -eq 0 ]
  run hts_sh 'hts_result ok a; hts_result fail b "boom"; hts_print_summary >/dev/null'
  [ "$status" -eq 1 ]
}

# ─── backup_file ──────────────────────────────────────────────────────────────
@test "backup_file: copies an existing file and records a backup row" {
  echo original > "$HOME/.zshrc"
  run hts_sh 'HTS_RUN_TS=20240101_000000; backup_file "$HOME/.zshrc"; cat "$HTS_BACKUP_ROOT/20240101_000000/.zshrc"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"original"* ]]
  grep -q "$(printf '\tbackup\t')" "$XDG_STATE_HOME/hts/manifest.tsv"
}

@test "backup_file: missing file is a no-op that returns 0" {
  run hts_sh 'backup_file "$HOME/nope"; echo rc=$?; if [ ! -d "$HTS_BACKUP_ROOT" ]; then echo no-backup-dir; fi'
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
  [[ "$output" == *"no-backup-dir"* ]]
}

@test "backup_file: twice in one run keeps the first copy and one manifest row" {
  echo first > "$HOME/.zshrc"
  run hts_sh '
    HTS_RUN_TS=20240101_000000
    backup_file "$HOME/.zshrc"
    echo second > "$HOME/.zshrc"
    backup_file "$HOME/.zshrc"
    cat "$HTS_BACKUP_ROOT/$HTS_RUN_TS/.zshrc"
    awk -F"\t" "\$2==\"backup\"" "$HTS_MANIFEST" | wc -l | tr -d " "'
  [ "$status" -eq 0 ]
  [[ "$output" == *"first"* ]]
  [[ "$output" != *"second"* ]]
  [[ "$output" == *"1" ]]
}

@test "backup_file: preserves file mode" {
  echo secret > "$HOME/.netrc"
  chmod 600 "$HOME/.netrc"
  run hts_sh 'HTS_RUN_TS=20240101_000000; backup_file "$HOME/.netrc"'
  [ "$status" -eq 0 ]
  [ "$(file_mode "$XDG_STATE_HOME/hts/backups/20240101_000000/.netrc")" = "-rw-------" ]
}

# ─── hts_download_verify ──────────────────────────────────────────────────────
@test "hts_download_verify: good digest keeps the file" {
  printf 'payload\n' > "$TEST_ROOT/src.bin"
  run hts_sh 'sum="$(hts_sha256 "$TEST_ROOT/src.bin")"; hts_download_verify "file://$TEST_ROOT/src.bin" "$sum" "$TEST_ROOT/out.bin"; cmp "$TEST_ROOT/src.bin" "$TEST_ROOT/out.bin"'
  [ "$status" -eq 0 ]
}

@test "hts_download_verify: uppercase digest is accepted" {
  printf 'payload\n' > "$TEST_ROOT/src.bin"
  run hts_sh 'sum="$(hts_sha256 "$TEST_ROOT/src.bin" | tr a-f A-F)"; hts_download_verify "file://$TEST_ROOT/src.bin" "$sum" "$TEST_ROOT/out.bin"'
  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/out.bin" ]
}

@test "hts_download_verify: bad digest fails and deletes the file" {
  printf 'payload\n' > "$TEST_ROOT/src.bin"
  run hts_sh 'hts_download_verify "file://$TEST_ROOT/src.bin" "$(printf "0%.0s" $(seq 1 64))" "$TEST_ROOT/out.bin"'
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/out.bin" ]
}

@test "hts_download_verify: missing URL fails and leaves nothing behind" {
  run hts_sh 'hts_download_verify "file://$TEST_ROOT/does-not-exist" "$(printf "0%.0s" $(seq 1 64))" "$TEST_ROOT/out.bin"'
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/out.bin" ]
  [ -z "$(ls "$TEST_ROOT" | grep 'out.bin.part' || true)" ]
}

# ─── hts_run_remote_script ────────────────────────────────────────────────────
@test "hts_run_remote_script: runs the script with its arguments" {
  printf 'echo "args:$*" > "$TEST_ROOT/ran"\n' > "$TEST_ROOT/s.sh"
  run hts_sh 'hts_run_remote_script "file://$TEST_ROOT/s.sh" bash one two'
  [ "$status" -eq 0 ]
  grep -q "args:one two" "$TEST_ROOT/ran"
}

@test "hts_run_remote_script: multi-word interpreter works" {
  printf 'echo "$MYVAR" > "$TEST_ROOT/ran"\n' > "$TEST_ROOT/s.sh"
  run hts_sh 'hts_run_remote_script "file://$TEST_ROOT/s.sh" "env MYVAR=hello bash"'
  [ "$status" -eq 0 ]
  grep -q hello "$TEST_ROOT/ran"
}

@test "hts_run_remote_script: missing URL fails" {
  run hts_sh 'hts_run_remote_script "file://$TEST_ROOT/missing.sh" bash'
  [ "$status" -ne 0 ]
}

@test "hts_run_remote_script: empty script fails and the interpreter is not run" {
  : > "$TEST_ROOT/empty.sh"
  printf '#!/bin/sh\ntouch "$TEST_ROOT/interp-ran"\n' > "$TEST_ROOT/interp"
  chmod +x "$TEST_ROOT/interp"
  run hts_sh 'hts_run_remote_script "file://$TEST_ROOT/empty.sh" "$TEST_ROOT/interp"'
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/interp-ran" ]
}

@test "hts_run_remote_script: propagates the script's exit code" {
  printf 'exit 7\n' > "$TEST_ROOT/s.sh"
  run hts_sh 'rc=0; hts_run_remote_script "file://$TEST_ROOT/s.sh" bash || rc=$?; exit $rc'
  [ "$status" -eq 7 ]
}

@test "hts_run_remote_script: leaves no temp script behind" {
  printf 'true\n' > "$TEST_ROOT/s.sh"
  run hts_sh 'hts_run_remote_script "file://$TEST_ROOT/s.sh" bash'
  [ "$status" -eq 0 ]
  [ -z "$(ls "$TMPDIR" | grep hts-remote || true)" ]
}
