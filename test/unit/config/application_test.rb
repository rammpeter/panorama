require 'test_helper'

class ApplicationTest < ActionView::TestCase
  setup do
  end

  test "load application successful" do
    assert_nothing_raised do
      config_file_name = "#{Dir.tmpdir}/test_panorama_config.yml"
      File.open(config_file_name, 'w') do |file|
        file.puts "SECRET_KEY_BASE: 5484235198p2531589230952815723187562731532621756"
      end

      [
        {
          PANORAMA_CONFIG_FILE: nil,
          PANORAMA_VAR_HOME: nil,
        },
        {
          PANORAMA_CONFIG_FILE: config_file_name,
          PANORAMA_VAR_HOME: "#{Dir.tmpdir}/test_panorama_var_home",
        },
        {
          PANORAMA_CONFIG_FILE: config_file_name,
          PANORAMA_VAR_HOME: nil,
        }
      ].each do |new_env|
        # Set the env according to new_env
        new_env.each do |key, value|
          ENV[key.to_s] = value
          ENV.delete(key.to_s) if value.nil?
        end

        # Load the class/module again although it is already loaded
        load 'config/application.rb'
      end
    end
  end



end
