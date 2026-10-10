setup() {
  load test_helper
  deploy_script="$BATS_TEST_DIRNAME/../deploy-vps.sh"
}

@test "should print the usage when --help is given" {
  run bash "$deploy_script" --help
  assert_success
  assert_line --index 0 "Usage: sudo bash deploy-vps.sh [command]"
}

@test "should print the usage and fail when the command is unknown" {
  run bash "$deploy_script" deploy
  assert_failure
  assert_line --index 0 "Usage: sudo bash deploy-vps.sh [command]"
}

@test "should refuse to install when not run as root" {
  run bash "$deploy_script" install < /dev/null
  assert_failure
  assert_output --partial "must be run as root"
}
