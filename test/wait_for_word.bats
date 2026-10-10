setup() {
  load test_helper
}

@test "should return once the expected word is typed" {
  run --separate-stderr wait_for_word noted <<< $'ok\nnoted'
  assert_success
}

@test "should fail when input runs out before the word is typed" {
  run --separate-stderr wait_for_word noted <<< "ok"
  assert_failure
}
