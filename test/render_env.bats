setup() {
  load test_helper
}

@test "should contain the server secret key" {
  run render_env "secret123" "master456" "My server" ""
  assert_success
  assert_line "ORGANIC_SECRET_KEY=secret123"
}

@test "should contain the master key" {
  run render_env "secret123" "master456" "My server" ""
  assert_line "ORGANIC_MASTER_KEY=master456"
}

@test "should contain the server name, spaces included" {
  run render_env "secret123" "master456" "My server" ""
  assert_line "ORGANIC_SERVER_NAME=My server"
}

@test "should contain the extra CORS origins" {
  run render_env "secret123" "master456" "My server" "https://app.example.org"
  assert_line "CORS_EXTRA_ORIGINS=https://app.example.org"
}

@test "should pin the node port to the one Caddy proxies to" {
  run render_env "secret123" "master456" "My server" ""
  assert_line "NODE_LOCAL_PORT=8080"
}
