source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# add jRuby versions by ruby-install jruby-9.4.7.0
# use chruby to switch between ruby versions
# ruby '3.1.4'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
# gem 'rails', '~> 6.1.7', '>= 6.1.7.2'

# Alternative instead of complete rails including actioncable etc., prev. version was 6.0.4
# rails_version = "7.0.0" # requires ruby >= 2.7.0 but jRuby 9.3.2.0 is compatible with ruby 2.6 only
# see: https://rubygems.org/gems/rails/versions
# rails_version = "6.1.7.10"
rails_version = "8.0.2.1"
#gem 'rails', rails_version
gem 'activerecord', rails_version
gem 'activemodel', rails_version
gem 'actionpack', rails_version
gem 'actionview', rails_version
# gem 'actionmailer', rails_version
gem 'activejob', rails_version
gem 'activesupport', rails_version
gem 'railties', rails_version

# 2025-04-23 avoid error with rel. 0.5.7: NameError: uninitialized constant Net::IMAP::Config::AttrTypeCoercion::Ractor
# gem 'net-imap', '0.5.6'

# to avoid "no such file to load -- sprockets/railtie" or "NoMethodError: undefined method `assets' for #<Rails::Application::Configuration"
# if sass-rails is moved to group :development
gem 'sprockets-rails'

# Use Puma as the app server
# gem 'puma', '~> 5.0'
gem 'puma'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# 2025-01-22 concurrent-ruby 1.3.5 raises: NameError: uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger
# gem 'concurrent-ruby', '1.3.4'

# gem 'activerecord-oracle_enhanced-adapter', github: "rsim/oracle-enhanced", branch: "release70"
# gem 'activerecord-oracle_enhanced-adapter'
# Avoid dependency on oci8, see https://github.com/rsim/oracle-enhanced/issues/2350
# gem "activerecord-oracle_enhanced-adapter", github: "rsim/oracle-enhanced", branch: "release71"
gem "activerecord-oracle_enhanced-adapter", github: 'rammpeter/oracle-enhanced', branch: 'release80'
gem 'activerecord-nulldb-adapter'

# Use Json Web Token (JWT) for token based authentication
gem 'jwt'

# Used for XMl processing in bequeathed packages
gem 'rexml'

#### certain dependencies fixed to version according to system gems to be equal with default Gems in x86-64-linux
gem 'jar-dependencies', '0.5.4' # Fix: You have already activated jar-dependencies 0.5.4, but your Gemfile requires jar-dependencies 0.5.5.
gem 'psych', '5.2.3'

group :development do
  # Ensure that the whole rails is installed in development environment, but not used in dev exec., especially to call "rails server"
  gem 'rails', rails_version
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'listen', '~> 3.3'
  # Use SCSS for stylesheets
  gem 'sass-rails', '>= 6'

  # Needed to build executable lock_jars for jar-dependencies
  gem 'ruby-maven', '~> 3.9'

  # Needed by net-imap, but not installed by default: Prevent from No such file or directory - /Users/pramm/.rubies/jruby-9.4.3.0/lib/ruby/gems/shared/gems/date-3.3.3-java
  #gem 'date'

  # gem 'jarbler', :git => 'https://github.com/rammpeter/jarbler.git', branch: 'pramm'
  # gem 'jarbler', github: 'rammpeter/jarbler', branch: 'pramm'
  # jarbler is installed by build_jar.sh, not needed in Gemfile
  # gem 'jarbler'

  gem 'brakeman'

  # Needed to build warfile
  # gem 'jruby-jars'
  # gem 'jruby-rack'
  # gem 'ruby-debug-base', name: '/Users/pramm/Downloads/ruby-debug-base-0.11.0-java.gem'
  # gem 'ruby-debug-ide'
end

group :test do
  # alternative to selenium
  gem 'playwright-ruby-client'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:windows, :jruby]

# Build Panorama.war with warbler (./build_war.sh), Use warbler directly from git
# gem install specific_install
# gem specific_install https://github.com/jruby/warbler.git

# Adding warbler this waay sadly doesn't install the executable warble
#group :development do
#  gem 'warbler', :git => 'https://github.com/jruby/warbler.git'
#end
