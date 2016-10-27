require 'panorama/engine'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount Panorama::Engine => "/panorama"

  root  'panorama/env#index'

end
