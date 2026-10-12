require 'test_helper'

class ApplicationTest < ActionView::TestCase
  # The test reloads config/application.rb while Rails is already initialized.
  # This executes config.load_defaults etc. again and changes the config of the running application
  # (e.g. re-adds keys to config.action_view which Rails has already removed in after_initialize,
  # leading to "NoMethodError: undefined method 'apply_stylesheet_media_default=' for class ActionView::Base"
  # in subsequent tests if ActionView::Base is loaded the first time after this test).
  # Therefore the config is saved before and restored after the test.
  setup do
    @saved_railtie_options  = snapshot_config_hash(railtie_config_options)
    @saved_app_config_ivars = Rails.application.config.instance_variables.to_h do |name|
      [name, snapshot_config_value(Rails.application.config.instance_variable_get(name))]
    end
  end

  teardown do
    restore_config_hash(railtie_config_options, @saved_railtie_options)

    app_config = Rails.application.config
    (app_config.instance_variables - @saved_app_config_ivars.keys).each do |name|
      app_config.remove_instance_variable(name)                                 # instance variable did not exist before the test
    end
    @saved_app_config_ivars.each do |name, saved|
      current = app_config.instance_variable_get(name)
      restored = restore_config_value(current, saved)
      app_config.instance_variable_set(name, restored) unless restored.equal?(current)
    end

    assert_equal @saved_railtie_options[:action_view][:content].keys, Rails.application.config.action_view.keys,
                 'config.action_view should have the same keys like before the test'
  end

  private

  # The hash where Rails stores all config values that are not explicit attributes of the config class
  # like config.action_view, config.assets, config.panorama_var_home etc.
  def railtie_config_options
    Rails::Railtie::Configuration.class_variable_get(:@@options)
  end

  # Remember the object itself and for Hash and Array also a copy of the content,
  # because the reload changes the content of these objects in place (e.g. config.assets.paths << ...)
  def snapshot_config_value(value)
    case value
    when Hash  then { object: value, content: snapshot_config_hash(value) }
    when Array then { object: value, content: value.dup }
    else            { object: value }
    end
  end

  def snapshot_config_hash(hash)
    hash.each_with_object({}) { |(k, v), result| result[k] = snapshot_config_value(v) }  # not to_h with block, because it is overwritten without block by some Hash subclasses of Rails
  end

  # Restore the content in place to preserve the object identity, because other objects may hold references on it
  # @return the object that should be the value again
  def restore_config_value(current, saved)
    original = saved[:object]
    return original if !saved.key?(:content) || original.frozen?
    if original.is_a?(Hash)
      restore_config_hash(original, saved[:content])
    else
      original.replace(saved[:content])
    end
    original
  end

  def restore_config_hash(hash, saved_content)
    (hash.keys - saved_content.keys).each { |k| hash.delete(k) }                # remove keys added by the reload
    saved_content.each do |k, saved|
      restored = restore_config_value(hash[k], saved)
      hash[k] = restored unless hash.key?(k) && hash[k].equal?(restored)
    end
  end

  public

  test "load application successful" do
    assert_nothing_raised do
      config_file_name = "#{Dir.tmpdir}/test_panorama_config.yml"
      File.open(config_file_name, 'w') do |file|
        file.puts "SECRET_KEY_BASE: 5484235198p253158923095281572318fqwfnuiui589hufh9rh8e7nccgng72228g37tvbq12xingoc3g2mfx8g6fxigo31ig198onqngxf1h8x1g7ng7xgcdhj1ah7562731532621756"
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
        origin_touched_env = {}                                                 # Remember origin values to restore

        # Set the env according to new_env
        new_env.each do |key, value|
          origin_touched_env[key] = ENV[key.to_s]
          ENV[key.to_s] = value
          ENV.delete(key.to_s) if value.nil?
        end

        # Load the class/module again although it is already loaded
        load 'config/application.rb'

        origin_touched_env.each do |key, value|
          ENV[key.to_s] = value                                                 # Restore the original value
          ENV.delete(key.to_s) if value.nil?
        end
      end
    end
  end



end
