require 'test_helper'

class EncryptionTest < ActiveSupport::TestCase

  test "encrypt_decrypt" do
    value = "This is a secret"
    salt = Random.new.bytes(16)
    encrypted_value = Encryption.encrypt_value(value, salt)
    decrypted_value = Encryption.decrypt_value(encrypted_value, salt)
    assert_equal decrypted_value, value, "Decrypted value should be the same"
  end

  test "ssh keys" do
    pub_key = Encryption.ssh_public_key
    puts pub_key
  end

end
