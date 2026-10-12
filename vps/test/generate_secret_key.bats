setup() {
  load test_helper
}

@test "should output 64 lowercase hexadecimal characters" {
  run generate_secret_key
  assert_success
  assert_output --regexp '^[0-9a-f]{64}$'
}

@test "should output a different key on each call" {
  first_key="$(generate_secret_key)"
  second_key="$(generate_secret_key)"
  assert_not_equal "$first_key" "$second_key"
}
