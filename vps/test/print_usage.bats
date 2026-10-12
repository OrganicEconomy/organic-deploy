setup() {
  load test_helper
}

@test "should describe the install command" {
  run print_usage
  assert_success
  assert_output --partial "install"
}

@test "should describe the update command" {
  run print_usage
  assert_output --partial "update"
}

@test "should describe the help command and its aliases" {
  run print_usage
  assert_output --partial "help, -h, --help"
}

@test "should state that the script must run as root" {
  run print_usage
  assert_output --partial "must be run as root"
}
