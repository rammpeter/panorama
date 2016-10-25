Rails.application.routes.draw do
  # route geenrated from rails engine
  # mount Panorama::Engine => "/panorama"

  mount Panorama::Engine => "/panorama"

  root  'panorama/env#index'
end
