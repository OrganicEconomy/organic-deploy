setup() {
  load test_helper
}

@test "should print the answer typed by the user" {
  run --separate-stderr ask "Server name" <<< "My server"
  assert_success
  assert_output "My server"
}

@test "should show the question on stderr" {
  run --separate-stderr ask "Server name" <<< "My server"
  assert_equal "$stderr" "Server name:"
}

@test "should print the default when the answer is empty" {
  run --separate-stderr ask "Backup retention in days" 14 <<< ""
  assert_output "14"
}

@test "should fail when there is nothing left to read" {
  run --separate-stderr ask "Server name" < /dev/null
  assert_failure
}
