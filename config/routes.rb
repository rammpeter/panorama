Panorama::Engine.routes.draw do
  #root :to => 'env#index', as: "default_panorama_root"+Random.rand(1000).to_s

  #root  'panorama/env#index'

  #get 'env/index', to: 'panorama/env#index'

  # Assure that all controller classes are loaded no matter how config.eager_load is set
  Rails.logger.info "###### set routes for all controller methods"
  Dir.glob("#{__dir__}/../app/controllers/panorama/*.rb") do |fname|
    controller_short_name = nil
    public_actions = true                                                       # following actions are public
    File.open(fname) do |f|
      f.each do |line|

        # find classname in file
        if line.match(/^ *class /)
          controller_name = line.split[1]
          controller_short_name = controller_name.underscore.gsub(/_controller/, '').gsub(/panorama\//, '')
          # Rails.logger.info "set routes for all following methods in file #{fname} for #{controller_name}"
        end

        public_actions = true  if line.match(/^ *public */)
        public_actions = false if line.match(/^ *private */)

        # Find methods in file
        if line.match(/^ *def /)
          if !controller_short_name.nil?
            action_name = line.gsub(/\(/, ' ').split[1]
            if !action_name.match(/\?/) && public_actions
              # set route for controllers action
              #Rails.logger.info "set route for #{controller_short_name}/#{action_name}"
              get  "#{controller_short_name}/#{action_name}"
              post "#{controller_short_name}/#{action_name}"

              # if controller is ApplicationController than set route for ApplicationController's methods for all controllers
            end
          end
        end
      end
    end
  end

=begin
  # Create route for every controller action for http-verb get and post
  Panorama::ApplicationController.descendants.each do |c|
    Rails.logger.info "set routes for all action_methods of #{c.name}"

    controller_short_name = c.name.underscore.gsub(/_controller/, '').gsub(/panorama\//, '')
    c.action_methods.each do |action_name|
      get  "#{controller_short_name}/#{action_name}", to: "#{controller_short_name}##{action_name}"
      post "#{controller_short_name}/#{action_name}", to: "#{controller_short_name}##{action_name}"
      # Rails.logger.info "set route for #{controller_short_name}/#{action_name}"
    end
  end
=end
end
