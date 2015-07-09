source 'https://rubygems.org'

# Alle Abhängigkeiten von Panorama-Gem übernehmen

# Variante für build war-file
gem 'Panorama', :git => 'http://github.com/rammpeter/Panorama_Gem'

# Development-Variante mit direktem File-Zugriff
#gem 'Panorama', path: '~/Documents/Projekte/Panorama_OpenSource'

# so lange keine 4.2-fähige Version des adapter raus ist
#gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'rails42'
gem 'activerecord-oracle_enhanced-adapter', git: 'http://github.com/rsim/oracle-enhanced', branch: 'rails42'


group :development, :test do
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Prevent this error on Oracle-JVM with sprockets v. 3.1.0 :
# NotImplementedError (fstat unimplemented unsupported or native support failed to load):
#   org/jruby/RubyFile.java:1138:in `size'
#   gems/gems/sprockets-3.1.0/lib/sprockets/cache/file_store.rb:110:in `set'
gem 'sprockets', '2.12.3'

