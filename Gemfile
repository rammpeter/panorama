source 'https://rubygems.org'

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.


# Alle Abhängigkeiten von Panorama-Gem übernehmen

# Variante für build war-file
gem 'Panorama', :git => 'http://github.com/rammpeter/Panorama_Gem'

# Development-Variante mit direktem File-Zugriff
#gem 'Panorama', path: '~/Documents/Projekte/Panorama_OpenSource'

# so lange keine 4.2-fähige Version des adapter raus ist
#gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'rails42'
# gem 'activerecord-oracle_enhanced-adapter', git: 'http://github.com/rsim/oracle-enhanced', branch: 'rails42'
gem 'activerecord-oracle_enhanced-adapter', "~> 1.7.2"

#gem 'activerecord-nulldb-adapter', github: 'mnoack/nulldb', branch: 'rails5'
gem 'activerecord-nulldb-adapter', :git => 'http://github.com/mnoack/nulldb', :branch =>'rails5'


gem 'listen', group: :development


group :development, :test do
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Prevent this error on Oracle-JVM with sprockets v. 3.1.0 :
# NotImplementedError (fstat unimplemented unsupported or native support failed to load):
#   org/jruby/RubyFile.java:1138:in `size'
#   gems/gems/sprockets-3.1.0/lib/sprockets/cache/file_store.rb:110:in `set'
# gem 'sprockets', '2.12.3'

