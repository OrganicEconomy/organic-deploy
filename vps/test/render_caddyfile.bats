setup() {
  load test_helper
}

@test "should open a site block for the domain" {
  run render_caddyfile test.economie-organique.fr
  assert_success
  assert_line "test.economie-organique.fr {"
}

@test "should proxy to the node server over IPv4 loopback" {
  run render_caddyfile test.economie-organique.fr
  assert_line "    reverse_proxy 127.0.0.1:8080"
}
