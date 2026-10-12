setup() {
  load test_helper
  backup_dir="$BATS_TEST_TMPDIR/backups"
  backup_script="$BATS_TEST_TMPDIR/organic-backup"
  mkdir -p "$backup_dir" "$BATS_TEST_TMPDIR/bin"
  stub_sqlite3_to_copy_the_database
  render_backup_script "$BATS_TEST_TMPDIR/organic.sqlite" "$backup_dir" 14 > "$backup_script"
}

stub_sqlite3_to_copy_the_database() {
  cat > "$BATS_TEST_TMPDIR/bin/sqlite3" <<'STUB'
#!/usr/bin/env bash
target="${2#.backup }"
cp "$1" "${target//\'/}"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/sqlite3"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  echo "database content" > "$BATS_TEST_TMPDIR/organic.sqlite"
}

@test "should back up the database into a file named after today" {
  run bash "$backup_script"
  assert_success
  assert_equal "$(cat "$backup_dir/organic-$(date +%F).sqlite")" "database content"
}

@test "should delete backups older than the retention period" {
  touch -d "20 days ago" "$backup_dir/organic-old.sqlite"
  run bash "$backup_script"
  [ ! -e "$backup_dir/organic-old.sqlite" ]
}

@test "should keep backups within the retention period" {
  touch -d "10 days ago" "$backup_dir/organic-recent.sqlite"
  run bash "$backup_script"
  [ -e "$backup_dir/organic-recent.sqlite" ]
}
