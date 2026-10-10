setup() {
  load test_helper
}

@test "should accept an ed25519 public key" {
  run is_valid_ssh_public_key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl user@laptop"
  assert_success
}

@test "should reject a private key pasted by mistake" {
  run is_valid_ssh_public_key "-----BEGIN OPENSSH PRIVATE KEY-----"
  assert_failure
}

@test "should accept an rsa public key" {
  run is_valid_ssh_public_key "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 user@laptop"
  assert_success
}

@test "should accept an ecdsa public key" {
  run is_valid_ssh_public_key "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY= user@laptop"
  assert_success
}
