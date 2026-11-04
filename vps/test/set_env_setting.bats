setup() {
  load test_helper
  env_file="$BATS_TEST_TMPDIR/.env"
}

@test "should append the setting when the env file lacks it" {
  echo "ORGANIC_SERVER_NAME=My server" > "$env_file"
  set_env_setting "$env_file" NODE_ENV production
  run cat "$env_file"
  assert_line "NODE_ENV=production"
}

@test "should replace the value when the setting is already there" {
  echo "NODE_ENV=dev" > "$env_file"
  set_env_setting "$env_file" NODE_ENV production
  run cat "$env_file"
  assert_output "NODE_ENV=production"
}

@test "should leave the server keys untouched" {
  render_env "secret123" "master456" "My server" "" > "$env_file"
  set_env_setting "$env_file" NODE_ENV production
  run cat "$env_file"
  assert_line "ORGANIC_SECRET_KEY=secret123"
  assert_line "ORGANIC_MASTER_KEY=master456"
}
