setup() {
  load test_helper
}

@test "should return once the expected text is typed" {
  run --separate-stderr wait_until_typed noted <<< $'ok\nnoted'
  assert_success
}

@test "should fail when input runs out before the text is typed" {
  run --separate-stderr wait_until_typed noted <<< "ok"
  assert_failure
}

@test "should accept a whole sentence as the expected text" {
  run --separate-stderr wait_until_typed "gus can log in and sudo" <<< $'ok\ngus can log in and sudo'
  assert_success
}
