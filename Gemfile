source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
# gem 'rails', '~> 6.1.7', '>= 6.1.7.2'

# Alternative instead of complete rails including actioncable etc., prev. version was 6.0.4
# rails_version = "7.0.0" # requires ruby >= 2.7.0 but jRuby 9.3.2.0 is compatible with ruby 2.6 only
# see: https://rubygems.org/gems/rails/versions
rails_version = "6.1.7.3"
# rails_version = "7.0.4"
#gem 'rails', rails_version
gem 'activerecord', rails_version
gem 'activemodel', rails_version
gem 'actionpack', rails_version
gem 'actionview', rails_version
gem 'actionmailer', rails_version
gem 'activejob', rails_version
gem 'activesupport', rails_version
gem 'railties', rails_version

# to avoid "no such file to load -- sprockets/railtie" or "NoMethodError: undefined method `assets' for #<Rails::Application::Configuration"
# if sass-rails is moved to group :development
gem 'sprockets-rails'

# Use Puma as the app server
gem 'puma', '~> 5.0'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# TODO: start really needed?
# Use Uglifier as compressor for JavaScript assets
#gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
#gem 'therubyrhino'
# Use jquery as the JavaScript library
#gem 'jquery-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
#gem 'jbuilder'

# TODO: end really needed?

# gem 'activerecord-oracle_enhanced-adapter', github: "rsim/oracle-enhanced", branch: "release70"
gem 'activerecord-oracle_enhanced-adapter'
gem 'activerecord-nulldb-adapter'

# TODO: i18n 1.8.8, 1.8.9 leads to Uncaught exception: undefined method `deep_merge!' for {}:Concurrent::Hash
# Check if following versions fix this error
# s.add_dependency 'i18n', '1.8.7'
gem 'i18n'

# Use Json Web Token (JWT) for token based authentication
gem 'jwt'

# Used for XMl processing in bequeathed packages
gem 'rexml'

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'listen', '~> 3.3'
  # Use SCSS for stylesheets
  gem 'sass-rails', '>= 6'

  gem 'jarbler'
  gem 'brakeman'

  # Needed to build warfile
  # gem 'jruby-jars'
  # gem 'jruby-rack'
end

group :test do
  # Ensure that the whole rails is installed in development environment, but not used in dev exec., especially to call "rails server"
  gem 'rails', rails_version
  # alternative to selenium
  gem 'playwright-ruby-client'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Build Panorama.war with warbler (./build_war.sh), Use warbler directly from git
# gem install specific_install
# gem specific_install https://github.com/jruby/warbler.git

# Adding warbler this waay sadly doesn't install the executable warble
#group :development do
#  gem 'warbler', :git => 'https://github.com/jruby/warbler.git'
#end
