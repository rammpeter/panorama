# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Alternative aus rails plugin new ... fuer o.g. Sequenz
# $:.push File.expand_path("../lib", __FILE__)

require 'Panorama/version'

Gem::Specification.new do |spec|
  spec.name          = "Panorama"
  spec.version       = Panorama::VERSION
  spec.authors       = ["Peter Ramm"]
  spec.email         = ["Peter@ramm-oberhermsdorf.de"]
  spec.summary       = %q{Tool for monitoring performance issues of Oracle databases}
  spec.description   = %q{Web-tool for monitoring performance issues of Oracle databases.
Provides easy access to several internal information.
Aims to issues that are inadequately analyzed and presented by other existing tools such as Enterprise Manager.
}
  spec.homepage      = "https://github.com/rammpeter/Panorama"
  spec.license       = "GNU General Public License"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  #spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = Dir["test/**/*"]
  #spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 4.1.5"
  spec.add_dependency 'activerecord-nulldb-adapter'
  spec.add_dependency 'activerecord-oracle_enhanced-adapter'
  spec.add_dependency 'memcache-client'

  # JavaScript-Runtime für Server-Seite, wenn kein lokaler installiert ist wie z.B. nodejs (oft unter Linux der Fall)
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  spec.add_dependency  'therubyrhino'
  spec.add_dependency  'therubyrhino_jar'

  spec.add_dependency  'multi_json'
  spec.add_dependency  'uglifier'
  spec.add_dependency  'sass'
  spec.add_dependency 'jquery-rails'

# Require von jruby-openssl nicht notwendig, da Bestandteil von jRuby, explizite Angabe führt zu Fehlermeldung von warbler und rack-Fehler bei Ausführung
#gem 'jruby-openssl'
#gem 'bouncy-castle-java', require: false



  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

end
