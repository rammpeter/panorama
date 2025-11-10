require 'openssl'

class Encryption
  attr_reader :ssh_public_key

  public

  @@instance = nil
  # @return [Encryption] The singleton instance
  def self.get_instance
    @@instance = Encryption.new if @@instance == nil
    @@instance
  end

  # Client-spezifisches Verschlüsseln eines Wertes, Teil des secret liegt client-spezifisch als encrypted cookie im Browser des Clients
  def self.encrypt_value(raw_value, salt)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key(salt))
    crypt.encrypt_and_sign(raw_value)
  end

  # Client specific decryption of value,  part of the key is located client specific as encrypted cookie in the browser of the client
  def self.decrypt_value(encrypted_value, salt)
    crypt = ActiveSupport::MessageEncryptor.new(get_salted_encryption_key(salt))
    crypt.decrypt_and_verify(encrypted_value)
  end

  def self.ssh_public_key
    self.get_instance.ssh_public_key
  end

  private
  def self.get_salted_encryption_key(salt)
    #     "#{salt}#{Rails.application.secrets.secret_key_base}"       # Position of key after switch to config/secrets.yml
    "#{salt}#{Panorama::Application.config.secret_key_base}"                    # Position of key after switch to config/secrets.yml
  end

  def initialize
    generate_ssh_keys
  end

  def generate_ssh_keys
    key = OpenSSL::PKey::RSA.new(2048)

    # Format the public key for SSH authorized_keys
    public_key = OpenSSL::PKey::RSA.new(key.public_key.to_s) # Create a new RSA object
    @ssh_public_key = public_key.to_pem # Get PEM format

    # Private key in PEM format
    @ssh_private_key = key.to_pem
  end

end