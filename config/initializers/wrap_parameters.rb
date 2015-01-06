# Be sure to restart your server when you modify this file.

# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.

# Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: [:json] if respond_to?(:wrap_parameters)
end

# To enable root element in JSON for ActiveRecord objects.
# ActiveSupport.on_load(:active_record) do
#  self.include_root_in_json = true
# end


# ######### Alte Version vor Rails 4.2.0 ###########

# Be sure to restart your server when you modify this file.
#
# This file contains settings for ActionController::ParamsWrapper which
# is enabled by default.

# Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
#ActiveSupport.on_load(:action_controller) do
#  wrap_parameters format: [:json]
#end

# Disable root element in JSON by default.
#ActiveSupport.on_load(:active_record) do
#  self.include_root_in_json = false
#end



