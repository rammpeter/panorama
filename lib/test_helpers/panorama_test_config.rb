class PanoramaTestConfig
  @@test_config_logged = false

  # Get configuration for tests
  # @return [Hash]
  def self.test_config
    test_host         = ENV['TEST_HOST']        || 'localhost'
    test_port         = ENV['TEST_PORT']        || '1521'
    test_servicename  = ENV['TEST_SERVICENAME'] || 'ORCLPDB1'
    test_username     = ENV['TEST_USERNAME']    || 'panorama_test'
    test_password     = ENV['TEST_PASSWORD']    || 'panorama_test'
    test_syspassword  = ENV['TEST_SYSPASSWORD'] || 'oracle'
    test_tns          = ENV['TEST_TNS']         || "#{test_host}:#{test_port}/#{test_servicename}"

    config = {
        adapter:                  'nulldb',
        host:                     test_host,
        management_pack_license:  ENV['MANAGEMENT_PACK_LICENSE'] ? ENV['MANAGEMENT_PACK_LICENSE'].to_sym : :diagnostics_and_tuning_pack,
        modus:                    ENV['TEST_TNS'].nil? ? 'host' : 'tns',
        panorama_sampler_schema:  test_username,                                # Use test user for panorama-sampler if not specified
        password_decrypted:       test_password,
        port:                     test_port,
        privilege:                'normal',
        query_timeout:            900,                                         # Allow 15 minutes for query and 20 minutes for socket read timeout in tests
        sid:                      test_servicename,
        sid_usage:                :SERVICE_NAME,
        syspassword_decrypted:    test_syspassword,
        user:                     test_username,
        tns:                      test_tns,
        tns_or_host_port_sn:      ENV['TEST_TNS'] ? :TNS : :HOST_PORT_SN
    }

    unless @@test_config_logged
      if defined?(Rails) && defined?(Rails.logger) && !Rails.logger.nil?        # function is also used in rake tasks where no Rails is present
        Rails.logger.debug('Test config'){ "################ Test config #################" }
        config.each do |key, value|
          Rails.logger.debug('Test config'){ "#{key.to_s.ljust(20, ' ')}: #{value}" } unless key.to_s['password']
        end
        Rails.logger.debug('Test config'){ "##############################################" }
      end
      @@test_config_logged = true
    end

    config
  end
end