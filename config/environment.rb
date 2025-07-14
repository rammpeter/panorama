# Load the Rails application.
require_relative "application"

# Suppress warning about to_time_preserves_timezone
# new_framework_defaults.rb could be too late to set this
Rails.application.config.active_support.to_time_preserves_timezone = :zone

# Initialize the Rails application.
Rails.application.initialize!
