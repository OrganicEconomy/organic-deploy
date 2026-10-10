setup() {
  load test_helper
}

@test "should accept a lowercase name" {
  run is_valid_username gus
  assert_success
}

@test "should reject a name starting with a digit or containing uppercase" {
  run is_valid_username 1gus
  assert_failure
  run is_valid_username Gus
  assert_failure
}

@test "should reject root" {
  run is_valid_username root
  assert_failure
}

@test "should reject organic, the service account" {
  run is_valid_username organic
  assert_failure
}
