# Workaround for Caused by: org.jruby.exceptions.RaiseException: (NameError) missing class name (`org.jruby.ext.openssl.OpenSSL')


$LOAD_PATH.unshift 'uri:classloader:/META-INF/jruby.home/lib/ruby/shared'
require 'jopenssl'