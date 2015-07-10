# Vermeiden der Fehlermeldung:
# OpenSSL::Cipher::CipherError
# Illegal key size: possibly you need to install Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files for your JRE

# Wirkt ab Java 7

# Quelle:
# http://stackoverflow.com/questions/14552303/opensslcipherciphererror-with-rails4-on-jruby

if RUBY_PLATFORM == 'java' # Allows the application to work with other Rubies if not JRuby
  require 'java'
  java_import 'java.lang.ClassNotFoundException'

  begin
    security_class = java.lang.Class.for_name('javax.crypto.JceSecurity')
    restricted_field = security_class.get_declared_field('isRestricted')
    restricted_field.accessible = true
    restricted_field.set nil, false
  rescue ClassNotFoundException => e
    # Handle Mac Java, etc not having this configuration setting
    $stderr.print "Java told me: #{e}n"
  end
end
