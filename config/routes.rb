Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root :to => 'env#index', as: "default_panorama_root"+Random.rand(1000).to_s

  #get  ':controller/:action'
  #post ':controller/:action'

  get  ':controller(/:action)'
  post ':controller(/:action)'
end
