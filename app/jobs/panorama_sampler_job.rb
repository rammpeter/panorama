require 'panorama_sampler_config'
require 'application_job'
require_relative '../helpers/exception_helper'

class PanoramaSamplerJob < ApplicationJob
  include ExceptionHelper

  queue_as :default

  SECONDS_LATE_ALLOWED = 3                                                      # x seconds delay after job creation are accepted

  @@first_call_after_startup = true                                             # Panorama has just started

  def perform(*args)

    if Rails.env.test?
      Rails.logger.error('PanoramaSamplerJob.perform') { "Should never be called in test here:\n#{Thread.current.backtrace.join("\n")}" }
    end

    snapshot_time = Time.now.round                                              # cut subseconds

    min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle               # smallest cycle in minutes

    # calculate next snapshot time from now
    last_snapshot_minute = snapshot_time.min-snapshot_time.min % min_snapshot_cycle
    last_snapshot_time = Time.new(snapshot_time.year, snapshot_time.month, snapshot_time.day, snapshot_time.hour, last_snapshot_minute, 0)
    next_snapshot_time = last_snapshot_time + min_snapshot_cycle * 60
    PanoramaSamplerJob.set(wait_until: next_snapshot_time).perform_later

#    if last_snapshot_time < snapshot_time-SECONDS_LATE_ALLOWED                  # Filter first Job execution at server startup, 2 seconds delay are allowed
#      Rails.logger.info "#{snapshot_time}: Job suspended because not started at exact snapshot time #{last_snapshot_time}"
#      return
#    end

    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_config_array.each do |config|
      Rails.logger.debug('PanoramaSamplerJob.perform') { "Processing config ID=#{config.get_id} name='#{config.get_name}'" }
      if @@first_call_after_startup
        config.reset_structure_check                                            # Ensure structure check is executed once at startup
        if config.get_domain_active(:AWR_ASH)
          begin
            snapshot_cycle_minutes  = config.get_domain_snapshot_cycle(:AWR_ASH)
            next_full_snapshot_time = Time.now                                  # look for next regular snapshot time from now
            next_full_snapshot_time += 60 - next_full_snapshot_time.sec         # Next full minute
            while snapshot_cycle_minutes > 60 && next_full_snapshot_time.hour % snapshot_cycle_minutes/60 != 0
              next_full_snapshot_time += 3600 - next_full_snapshot_time.min * 60      # next full hour
            end
            while snapshot_cycle_minutes <= 60 && next_full_snapshot_time.min % snapshot_cycle_minutes != 0
              next_full_snapshot_time += 60                                     # next full minute
            end
            prev_regular_snapshot_time = next_full_snapshot_time - snapshot_cycle_minutes * 60
            Rails.logger.debug('PanoramaSamplerJob.perform') { "First start of ASH sampler daemon after startup for config ID=#{config.get_id} name='#{config.get_name}' snapshot_time=#{prev_regular_snapshot_time}" }
            WorkerThread.run_ash_sampler_daemon(config, prev_regular_snapshot_time)   # start ASH daemon at first startup
          rescue Exception => e
            Rails.logger.error('PanoramaSamplerJob.perform') { "Exception #{e.message} raised in PanoramaSamplerJob.perform at startup ASH-init for config-ID=#{config.get_id}" }
              # Don't raise exception because it should not stop calling job processing
          end
        end
      else                                                                      # regular operation in snapshot cycle
        check_for_sampling(config, snapshot_time, :AWR_ASH)
        check_for_sampling(config, snapshot_time, :OBJECT_SIZE, 60)
        check_for_sampling(config, snapshot_time, :CACHE_OBJECTS)
        check_for_sampling(config, snapshot_time, :BLOCKING_LOCKS)
        check_for_sampling(config, snapshot_time, :LONGTERM_TREND, 60)
        WorkerThread.check_analyze(config) if config.any_domain_active?
      end
    end

    @@first_call_after_startup = false                                          # regular operation now
  rescue Exception => e
    Rails.logger.error('PanoramaSamplerJob.perform') { "Exception in PanoramaSamplerJob.perform:\n#{e.message}" }
    log_exception_backtrace(e, 40)
    raise e
  end


  private
  # Check if sampling should be executed
  # @param [PanoramaSamplerConfig] config
  # @param [Time] snapshot_time
  # @param [Symbol] domain
  # @param [Integer] minute_factor
  def check_for_sampling(config, snapshot_time, domain, minute_factor = 1)

    last_snapshot_start_key = "last_#{domain.downcase}_snapshot_start".to_sym
    snapshot_cycle_minutes  = config.get_domain_snapshot_cycle(domain) * minute_factor
    if snapshot_cycle_minutes.nil? || snapshot_cycle_minutes == 0 || !snapshot_cycle_minutes.instance_of?(Integer)
      Rails.logger.warn('PanoramaSamplerJob.check_for_sampling'){ "snapshot_cycle_minutes not valid, assuming 60: '#{snapshot_cycle_minutes}' of class #{snapshot_cycle_minutes.class}" }
      snapshot_cycle_minutes = 60
    end
    last_snapshot_start     = config.get_last_domain_snapshot_start(domain)

    if config.get_domain_active(domain) &&
      ((snapshot_cycle_minutes < 60    && snapshot_time.min % snapshot_cycle_minutes == 0 ) ||  # exact startup time at full hour + x*snapshot_cycle minutes
       (snapshot_time.min == 0  && snapshot_time.hour % snapshot_cycle_minutes/60 == 0)  # Full hour for snapshot cycle = n*hour
      )
      if  last_snapshot_start.nil? || (last_snapshot_start + snapshot_cycle_minutes.minutes <= snapshot_time+SECONDS_LATE_ALLOWED)  # snapshot_cycle expired ?, 2 seconds delay are allowed
        config.set_domain_last_snapshot_start(domain, snapshot_time)
        WorkerThread.create_snapshot(config, snapshot_time, domain)
      else
        if snapshot_cycle_minutes < 1440
          Rails.logger.warn('PanoramaSamplerJob.check_for_sampling') { "#{Time.now}: Last #{domain} snapshot start (#{last_snapshot_start}) not old enough to expire next snapshot after #{snapshot_cycle_minutes} minutes for ID=#{config.get_id} '#{config.get_name}'" }
          Rails.logger.warn('PanoramaSamplerJob.check_for_sampling') { "May be sampling is done by multiple Panorama instances?" }
          Rails.logger.warn('PanoramaSamplerJob.check_for_sampling') { "This can also happen one time after startup of Panorama." }
        end
      end
    end
  end

end
