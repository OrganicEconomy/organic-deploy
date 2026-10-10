setup() {
  load test_helper
}

@test "should run the server as the organic user" {
  run render_systemd_unit
  assert_success
  assert_line "User=organic"
}

@test "should run from the server checkout" {
  run render_systemd_unit
  assert_line "WorkingDirectory=/home/organic/organic-webserver/organic-webserver"
}

@test "should load the server .env" {
  run render_systemd_unit
  assert_line "EnvironmentFile=/home/organic/organic-webserver/organic-webserver/.env"
}

@test "should start the server through tsx" {
  run render_systemd_unit
  assert_line "ExecStart=/usr/bin/node --import tsx server.ts"
}

@test "should restart the server when it crashes" {
  run render_systemd_unit
  assert_line "Restart=on-failure"
}

@test "should start the server at boot" {
  run render_systemd_unit
  assert_line "WantedBy=multi-user.target"
}
