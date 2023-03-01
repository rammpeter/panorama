require 'application_job'
require_relative '../helpers/exception_helper'

class InitializationJob < ApplicationJob
  include ExceptionHelper

  queue_as :default

  def perform(*args)
    ExceptionHelper.log_memory_state                                                            # Log memory values once at startup
  rescue Exception => e
    Rails.logger.error('InitializationJob.perform') { "#{e.class} #{e.message}" }
    log_exception_backtrace(e, 40)
    raise e
  end
end
