# Der Klassenname Application ist leider bereits anderweitig vergeben, so dass zu diesem Namen geriffen wurde
class Wsmethod < ActiveRecord::Base
  self.table_name =  "sysp.wsmethod"


  # Request-übergreifendes Caching des Models
  def self.get_cached_instance(id)
    Rails.cache.fetch("Wsmethod_#{id}") { self.find(id) }
  rescue Exception=>e
    Rails.logger.error e.message
    e.backtrace.each do |bt|
      Rails.logger.error bt
    end
    return nil
  end
end
