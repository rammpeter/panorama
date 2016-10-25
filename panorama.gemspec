$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "panorama/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name          = "Panorama"
  s.version       = Panorama::VERSION
  s.authors       = ["Peter Ramm"]
  s.email         = ["Peter@ramm-oberhermsdorf.de"]
  s.summary       = %q{Tool for monitoring performance issues of Oracle databases}
  s.description   = %q{Web-tool for monitoring performance issues of Oracle databases.
Provides easy access to several internal information.
Aims to issues that are inadequately analyzed and presented by other existing tools such as Enterprise Manager.
}
  s.homepage      = "https://github.com/rammpeter/Panorama_Gem"
  s.license       = "GNU General Public License"

  s.files = Dir["{app,config,lib}/**/*", "Rakefile", "README.md", "README.rdoc"]

  s.add_dependency "rails", "~> 5.0.0", ">= 5.0.0.1"

  s.add_dependency 'activerecord-nulldb-adapter'
  s.add_dependency 'activerecord-oracle_enhanced-adapter'     # lokal in Gemfile überschreiben mit : gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'rails42'

=begin
  # Rails 4 Varianten

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = Dir["test/**/*"]
  #spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails-html-sanitizer'
  spec.add_dependency 'activerecord-nulldb-adapter'
  spec.add_dependency 'activerecord-oracle_enhanced-adapter'     # lokal in Gemfile überschreiben mit : gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'rails42'
  spec.add_dependency "mime-types"	    # Prevent Gem::InstallError: mime-types-data requires Ruby version >= 2.0.

  # JavaScript-Runtime für Server-Seite, wenn kein lokaler installiert ist wie z.B. nodejs (oft unter Linux der Fall)
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  spec.add_dependency  'therubyrhino'
  spec.add_dependency  'therubyrhino_jar'

  spec.add_dependency  'multi_json'
  spec.add_dependency  'uglifier'
  spec.add_dependency  'sass'
  spec.add_dependency  'jquery-rails'
  spec.add_dependency  'turbolinks'
  spec.add_dependency  'tzinfo-data'    # Fixes error " No source of timezone data could be found " on windows systems

  # some Linux systems require krypt gem to fix following error
  # jruby.home/lib/ruby/shared/krypt/provider/jdk.rb:33 warning: no super class for `Krypt::Provider::JDK', Object assumed
  spec.add_dependency 'krypt-core'
  spec.add_dependency 'krypt-provider-jdk'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

=end

end
