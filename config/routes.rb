# Fix ActionController::RoutingError (uninitialized constant Panorama::EnvController) in Linux systems

$LOAD_PATH.each do |p|
  if p.match(/Panorama_Gem.*\/lib/)
    puts "####################### match #{p}"
    $LOAD_PATH << p.gsub('/lib', '/app/controllers')
    $LOAD_PATH << p.gsub('/lib', '/app/helpers')
    $LOAD_PATH << p.gsub('/lib', '/app/models')
  end
end

puts "################ $LOAD_PATH is :"
puts $LOAD_PATH
puts "################ end of $LOAD_PATH"


require 'panorama/engine'
require 'panorama/env_controller'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount Panorama::Engine => "/panorama"

  root  'panorama/env#index'

end
