setup() {
  load test_helper
}

@test "should accept a server name" {
  run is_not_empty "My server"
  assert_success
}

@test "should reject an empty value" {
  run is_not_empty ""
  assert_failure
}
