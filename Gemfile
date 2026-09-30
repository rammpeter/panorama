source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Alternative instead of complete rails including actioncable etc., prev. version was 6.0.4
# see: https://rubygems.org/gems/rails/versions
# rails_version = "6.1.7.10"
# rails_version = "8.0.5.1"
rails_version = "8.1.4"
gem 'activerecord', rails_version
gem 'activemodel', rails_version
gem 'actionpack', rails_version
gem 'actionview', rails_version
gem 'activejob', rails_version
gem 'activesupport', rails_version
gem 'railties', rails_version


# to avoid "no such file to load -- sprockets/railtie" or "NoMethodError: undefined method `assets' for #<Rails::Application::Configuration"
# if sass-rails is moved to group :development
gem 'sprockets-rails'

# Use Puma as the app server
# gem 'puma', '~> 5.0'
gem 'puma'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'

# gem 'activerecord-oracle_enhanced-adapter', github: "rsim/oracle-enhanced", branch: "release70"
# gem 'activerecord-oracle_enhanced-adapter'
# Avoid dependency on oci8, see https://github.com/rsim/oracle-enhanced/issues/2350
# gem "activerecord-oracle_enhanced-adapter", github: "rsim/oracle-enhanced", branch: "release71"

# Use branch releae80 with the last commit from 2025-06-29
# gem "activerecord-oracle_enhanced-adapter", github: 'rammpeter/oracle-enhanced', branch: 'release80', ref: 'c1094bc'
gem "activerecord-oracle_enhanced-adapter"
gem 'activerecord-nulldb-adapter'

# Use Json Web Token (JWT) for token based authentication
gem 'jwt'

# Used for XMl processing in bequeathed packages
gem 'rexml'

#### certain dependencies fixed to version according to system gems to be equal with default Gems in x86-64-linux or aarch64
# 2026-01-29 use current jar-dependencies
# gem 'jar-dependencies', '0.5.4' # Fix: You have already activated jar-dependencies 0.5.4, but your Gemfile requires jar-dependencies 0.5.5.
# gem 'psych', '5.2.3'
# gem 'io-console', '0.8.0'

group :development do
  # Ensure that the whole rails is installed in development environment, but not used in dev exec., especially to call "rails server"
  gem 'rails', rails_version
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler'
  gem 'listen'
  # Use SCSS for stylesheets
  # gem 'sass-rails', '>= 6'

  # Needed to build executable lock_jars for jar-dependencies
  # gem 'ruby-maven', '~> 3.9'

  # For dev use the same version as in default system gems, to prevent at debug: Uncaught exception: You have already activated date 3.4.1, but your Gemfile requires date 3.5.1.
  # gem 'date', '3.4.1'

  # gem 'rdoc', '< 8.0'
  # gem 'rbs', platforms: [:ruby]


  # gem 'jarbler', :git => 'https://github.com/rammpeter/jarbler.git', branch: 'pramm'
  # gem 'jarbler', github: 'rammpeter/jarbler', branch: 'pramm'
  # jarbler is installed by build_jar.sh, not needed in Gemfile
  # gem 'jarbler'

  gem 'brakeman'

  # Needed for the Debugger. Fix: LoadError: cannot load such file -- ostruct
  gem 'ostruct'

end

group :test do
  # alternative to selenium
  gem 'playwright-ruby-client'
  gem 'minitest', require: false
  # gem 'minitest', '5.26.0'  # Rel. 6.0.1 causes ArgumentError: wrong number of arguments (given 3, expected 1..2) at minitest-6.0.1/lib/minitest.rb:472
  # Probem fixed by change minitest.rb:472 "run self, method_name, reporter" to "Runnable.run self, method_name, reporter"
  # https://github.com/minitest/minitest/issues/1063
  # Since minitest 6 Minitest::Mock and Object#stub (require 'minitest/mock') are extracted into a separate gem
  gem 'minitest-mock', require: false

end

group :development, :test do
  # JavaScript minification at asset precompile time (config.assets.js_compressor = :terser).
  # Terser handles ES6. Requires a JS runtime for ExecJS at BUILD time only: Node.js on the build machine
  # (not bundled into the JAR, since assets are already precompiled there).
  # gem 'terser'
  gem 'pry-debugger-jruby'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:windows, :jruby]

# Exclude gems that are not really needed but may cause trouble
# fixes problems like: You have already activated erb 4.0.4, but your Gemfile requires erb 6.0.2.
no_require = File.readlines('excluded_gems.txt').map(&:strip).reject{|s| s.empty? || s.start_with?('#') }
no_require.each do |nr|
  name = nr.split(',')[0].strip
  version = nr.split(',')[1]&.strip
  unless ['minitest'].include?(name)
    if version
      gem name, version, require: false
    else
      gem name, require: false
    end
  end
end
