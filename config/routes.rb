

# Fix ActionController::RoutingError (uninitialized constant Panorama::EnvController) in Linux systems

#$LOAD_PATH.each do |p|
#  if p.match(/Panorama_Gem.*\/lib/)
#    puts "####################### match #{p}"
#    $LOAD_PATH << p.gsub('/lib', '/app/controllers')
#    $LOAD_PATH << p.gsub('/lib', '/app/helpers')
#    $LOAD_PATH << p.gsub('/lib', '/app/models')
#  end
#end

Rails.logger.info "################ $LOAD_PATH is :"
Rails.logger.info $LOAD_PATH
Rails.logger.info "################ end of $LOAD_PATH"

# Require controller only after addition of LOAD_PATH
#require 'env_controller'

# require all other controllers and helpers based on env_controller
#EnvController.require_all_controller_and_helpers_and_models

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  #mount Panorama::Engine => "/"

  # set routing info for engine
 # EnvController.routing_actions.each do |r|
 #   # puts "set route for #{r[:controller]}/#{r[:action]}"
 #   get  "#{r[:controller]}/#{r[:action]}"
 #   post  "#{r[:controller]}/#{r[:action]}"
 # end

  root  'env#index'

end
