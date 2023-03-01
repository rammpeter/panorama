# Activate background-processing for Panorama-Sampler

# require_relative '../../config/engine_config'
require_relative '../../app/jobs/connection_terminate_job'
require_relative '../../app/jobs/initialization_job'
require_relative '../../app/jobs/panorama_sampler_job'

# Wait async to proceed rails startup before first job execution

unless Rails.env.test?                                                          # Don't start the background jobs in test environment
  InitializationJob.set(wait: 1.seconds).perform_later
  PanoramaSamplerJob.set(wait: 5.seconds).perform_later if !Panorama::Application.config.panorama_master_password.nil?
  ConnectionTerminateJob.set(wait: 10.seconds).perform_later                      # Check connections for inactivity
else
  Rails.logger.debug('initialize_jobs.rb') { "Initializing jobs suppressed for test runs"}
end
