setup() {
  load test_helper
  env_file="$BATS_TEST_TMPDIR/.env"
}

@test "should succeed when the env file already holds a master key" {
  render_env "secret123" "master456" "My server" "" > "$env_file"
  run has_server_keys "$env_file"
  assert_success
}

@test "should fail when there is no env file yet" {
  run has_server_keys "$env_file"
  assert_failure
}

@test "should fail when the env file has an empty master key" {
  render_env "" "" "My server" "" > "$env_file"
  run has_server_keys "$env_file"
  assert_failure
}
