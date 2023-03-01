module Encryption
  public
  # Client-spezifisches Verschlüsseln eines Wertes, Teil des Schlüssels liegt client-spezifisch als verschlüsselter cookie im Browser des Clients
  def self.encrypt_value(raw_value, salt)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key(salt))
    crypt.encrypt_and_sign(raw_value)
  end

  # Client-spezifisches Entschlüsseln des Wertes,  Teil des Schlüssels liegt client-spezifisch als verschlüsselter cookie im Browser des Clients
  def self.decrypt_value(encrypted_value, salt)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key(salt))
    crypt.decrypt_and_verify(encrypted_value)
  end

  private
  def self.get_salted_encryption_key(salt)
    "#{salt}#{Rails.application.secrets.secret_key_base}"       # Position of key after switch to config/secrets.yml
  end


end