setup() {
  load test_helper
}

@test "should forbid root login" {
  run render_sshd_hardening gus
  assert_success
  assert_line "PermitRootLogin no"
}

@test "should forbid password login" {
  run render_sshd_hardening gus
  assert_line "PasswordAuthentication no"
}

@test "should only let the admin log in" {
  run render_sshd_hardening gus
  assert_line "AllowUsers gus"
}
