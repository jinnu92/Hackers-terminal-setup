#!/usr/bin/env bats
# --restore and --uninstall against a manifest built in a temp HOME.
load helpers

setup() { setup_env; }
teardown() { teardown_env; }

# Run a snippet as one installer "run" with its own timestamp.
as_run() {   # <timestamp> <snippet>
  hts_sh "HTS_RUN_TS=$1; $2"
}

@test "restore: picks the earliest backup of a file" {
  echo original > "$HOME/.zshrc"
  as_run 20240101_000001 'backup_file "$HOME/.zshrc"; echo v1 > "$HOME/.zshrc"; hts_track_file "$HOME/.zshrc"'
  as_run 20240102_000001 'backup_file "$HOME/.zshrc"; echo v2 > "$HOME/.zshrc"'
  [ "$(cat "$HOME/.zshrc")" = "v2" ]
  run_ter --restore -y
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "original" ]
}

@test "restore: a specific run timestamp restores that run's backup" {
  echo original > "$HOME/.zshrc"
  as_run 20240101_000001 'backup_file "$HOME/.zshrc"; echo v1 > "$HOME/.zshrc"'
  as_run 20240102_000001 'backup_file "$HOME/.zshrc"; echo v2 > "$HOME/.zshrc"'
  run_ter --restore 20240102_000001 -y
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "v1" ]
}

@test "restore: backs up the current file before overwriting it" {
  echo original > "$HOME/.zshrc"
  as_run 20240101_000001 'backup_file "$HOME/.zshrc"; echo changed > "$HOME/.zshrc"'
  run_ter --restore -y
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "original" ]
  # the "changed" version must still exist in some backup run
  grep -rq changed "$XDG_STATE_HOME/hts/backups"
}

@test "restore --dry-run changes nothing" {
  echo original > "$HOME/.zshrc"
  as_run 20240101_000001 'backup_file "$HOME/.zshrc"; echo changed > "$HOME/.zshrc"'
  run_ter --restore --dry-run
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "changed" ]
}

@test "uninstall: restores backed-up files, removes created files, leaves ~/workspace alone" {
  echo original > "$HOME/.zshrc"
  mkdir -p "$HOME/workspace/proj" "$HOME/.config/tool"
  echo mywork > "$HOME/workspace/proj/code.txt"
  as_run 20240101_000001 '
    backup_file "$HOME/.zshrc"
    echo installed > "$HOME/.zshrc"; hts_track_file "$HOME/.zshrc"
    echo made > "$HOME/.config/tool/created.conf"; hts_track_file "$HOME/.config/tool/created.conf"
    hts_track_file "$HOME/workspace"
    hts_manifest_add component --core "Core terminal"'
  run_ter --uninstall -y
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "original" ]
  [ ! -e "$HOME/.config/tool/created.conf" ]
  [ -f "$HOME/workspace/proj/code.txt" ]
  [ "$(cat "$HOME/workspace/proj/code.txt")" = "mywork" ]
  # manifest archived so a second uninstall is a no-op
  ls "$XDG_STATE_HOME"/hts/manifest.tsv.uninstalled-* >/dev/null
}

@test "uninstall --dry-run changes nothing" {
  mkdir -p "$HOME/.config/tool"
  echo made > "$HOME/.config/tool/created.conf"
  manifest_row file "$HOME/.config/tool/created.conf"
  run_ter --uninstall --dry-run
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/tool/created.conf" ]
  [ -s "$XDG_STATE_HOME/hts/manifest.tsv" ]
}

@test "uninstall: rejects crafted manifest lines and touches nothing they point at" {
  mkdir -p "$HOME/topdir" "$HOME/sub" "$HOME/.config"
  echo keep > "$HOME/topdir/file"
  echo victim > "$HOME/victim"
  echo keepme > "$HOME/.config/keep"
  etc_before="$(cksum < /etc/hosts)"
  manifest_row file "/etc/hosts"
  manifest_row file "$HOME"
  manifest_row file "$HOME/"
  manifest_row file "$HOME/sub/../victim"
  manifest_row file "$HOME/.."
  manifest_row file ""
  manifest_row file "relative/path"
  manifest_row file "$HOME/topdir"
  manifest_row file "/"
  run_ter --uninstall -y
  [ "$(cksum < /etc/hosts)" = "$etc_before" ]
  [ -d "$HOME" ]
  [ -f "$HOME/victim" ]
  [ -f "$HOME/topdir/file" ]
  [ -f "$HOME/.config/keep" ]
  [ -d "$HOME/sub" ]
}

@test "uninstall: a manifest path that is a symlink out of HOME is not followed" {
  mkdir -p "$TEST_ROOT/outside"
  echo precious > "$TEST_ROOT/outside/data"
  ln -s "$TEST_ROOT/outside" "$HOME/linkdir"
  manifest_row file "$HOME/linkdir/data"
  run_ter --uninstall -y
  [ -f "$TEST_ROOT/outside/data" ]
}

@test "uninstall: non-interactive without -y refuses and changes nothing" {
  mkdir -p "$HOME/.config/tool"
  echo made > "$HOME/.config/tool/created.conf"
  manifest_row file "$HOME/.config/tool/created.conf"
  run_ter --uninstall
  [ "$status" -ne 0 ]
  [ -f "$HOME/.config/tool/created.conf" ]
  [ -s "$XDG_STATE_HOME/hts/manifest.tsv" ]
}

@test "restore: non-interactive without -y refuses and changes nothing" {
  echo original > "$HOME/.zshrc"
  as_run 20240101_000001 'backup_file "$HOME/.zshrc"; echo changed > "$HOME/.zshrc"'
  run_ter --restore
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.zshrc")" = "changed" ]
}

@test "uninstall without a manifest is a harmless no-op" {
  run_ter --uninstall -y
  [ "$status" -eq 0 ]
  assert_no_stub_calls
}

@test "uninstall without --purge-tools never runs a package manager" {
  manifest_row tool wget apt
  manifest_row tool jq brew
  manifest_row tool somepkg pipx
  run_ter --uninstall -y
  assert_no_stub_calls
}

@test "--status reflects tracked components after a run" {
  as_run 20240101_000001 'hts_manifest_add component --core "Core terminal"'
  run_ter --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"--core"* ]]
}
