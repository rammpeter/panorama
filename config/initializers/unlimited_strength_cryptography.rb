# Vermeiden der Fehlermeldung:
# OpenSSL::Cipher::CipherError
# Illegal key size: possibly you need to install Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files for your JRE

# Wirkt ab Java 7

# Quelle:
# http://stackoverflow.com/questions/14552303/opensslcipherciphererror-with-rails4-on-jruby


#if RUBY_PLATFORM == 'java' # Allows the application to work with other Rubies if not JRuby
if false      # try to work without JCE fix, 2020-09-30
  require 'java'
  java_import 'java.lang.ClassNotFoundException'

  begin
    security_class = java.lang.Class.for_name('javax.crypto.JceSecurity')
    restricted_field = security_class.get_declared_field('isRestricted')
    restricted_field.accessible = true
    if restricted_field.get(nil)
      Rails.logger.info "Unlimited strength cryptography is not active for your current JRE/JDK, trying to fake it. If you don't want this, install Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files"
      restricted_field.set nil, false
    else
      Rails.logger.info "Unlimited strength cryptography is already active for your current JRE/JDK"
    end
  rescue ClassNotFoundException => e
    # Handle Mac Java, etc not having this configuration setting
    Rails.logger.error "unlimited_strength_cryptography.rb: ClassNotFoundException #{e}"
  rescue Exception => e
    Rails.logger.error "unlimited_strength_cryptography.rb: Error faking advanced JCE (#{e})!"
    Rails.logger.error "Please fix this by installing Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files"
    Rails.logger.error "This files are available at http://www.oracle.com/technetwork/java/javase/downloads/index.html"
  end
end
