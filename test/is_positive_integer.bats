setup() {
  load test_helper
}

@test "should accept a number of days" {
  run is_positive_integer 14
  assert_success
}

@test "should reject zero" {
  run is_positive_integer 0
  assert_failure
}

@test "should reject text" {
  run is_positive_integer two
  assert_failure
}
