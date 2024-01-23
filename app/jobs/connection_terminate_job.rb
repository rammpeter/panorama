require 'application_job'
require_relative '../helpers/exception_helper'

class ConnectionTerminateJob < ApplicationJob
  include ExceptionHelper

  queue_as :default
  CHECK_CYCLE_SECONDS = 3600                                                    # Terminate idle sessions with last active older than 60 minutes

  def perform(*args)
    ConnectionTerminateJob.set(wait_until: Time.now.round + CHECK_CYCLE_SECONDS).perform_later  # Schedule next start
    thread = Thread.new{PanoramaConnection.disconnect_aged_connections(CHECK_CYCLE_SECONDS)}
    thread.name = 'ConnectionTerminateJob'
    ClientInfoStore.cleanup                                                     # Remove expired cache entries
    UsageInfo.housekeeping                                                      # Remove expired usage info
  rescue Exception => e
    Rails.logger.error('ConnectionTerminateJob.perform') { "Exception #{e.class}\n#{e.message}" }
    log_exception_backtrace(e, 40)
    raise e
  end
end
