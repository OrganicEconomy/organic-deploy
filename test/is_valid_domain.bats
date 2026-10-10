setup() {
  load test_helper
}

@test "should accept a subdomain of a real domain" {
  run is_valid_domain test.economie-organique.fr
  assert_success
}

@test "should reject an empty domain" {
  run is_valid_domain ""
  assert_failure
}

@test "should reject a domain without any dot" {
  run is_valid_domain localhost
  assert_failure
}

@test "should reject a URL with a scheme" {
  run is_valid_domain https://test.economie-organique.fr
  assert_failure
}
