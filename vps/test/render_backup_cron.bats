setup() {
  load test_helper
}

@test "should run the backup as root every day at 3am" {
  run render_backup_cron /usr/local/bin/organic-backup
  assert_success
  assert_output "0 3 * * * root /usr/local/bin/organic-backup"
}
