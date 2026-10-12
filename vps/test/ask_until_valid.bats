setup() {
  load test_helper
}

@test "should ask again until the answer is valid" {
  run --separate-stderr ask_until_valid "Admin username" is_valid_username <<< $'Gus\ngus'
  assert_success
  assert_output "gus"
}

@test "should fail instead of looping forever when input runs out" {
  run --separate-stderr ask_until_valid "Admin username" is_valid_username <<< "Gus"
  assert_failure
}
