setup() {
  load test_helper
}

@test "should resolve to install when no argument is given" {
  run resolve_command
  assert_success
  assert_output "install"
}

@test "should resolve to update when update is given" {
  run resolve_command update
  assert_success
  assert_output "update"
}

@test "should resolve to help when -h is given" {
  run resolve_command -h
  assert_success
  assert_output "help"
}

@test "should resolve to help when --help is given" {
  run resolve_command --help
  assert_success
  assert_output "help"
}

@test "should fail when an unknown command is given" {
  run resolve_command deploy
  assert_failure
}

@test "should resolve to help when help is given" {
  run resolve_command help
  assert_success
  assert_output "help"
}
