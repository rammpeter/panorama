class Applexecution < ActiveRecord::Base
  self.table_name =  "sysp.applexecution"
  belongs_to :application,    :foreign_key => "id_application"
  belongs_to :whtransferdate, :foreign_key => "id_whtransferdate"
  belongs_to :applexecutionstatus, :foreign_key => "id_applexecutionstatus"
  # Der Begriff Application ist bereits besetzt
  belongs_to :application, :foreign_key => "id_application", :class_name=>"SyspApplication"
  has_one :applexecattr_startexecution, :foreign_key => "id_applexecution", 
    :class_name=>"Applexecattr", :conditions => "id_gaattr=755"
  has_one :applexecattr_endexecution, :foreign_key => "id_applexecution", 
    :class_name=>"Applexecattr", :conditions => "id_gaattr=756"

  # Request-übergreifendes Caching des Models
  def self.get_cached_instance(id)
    Rails.cache.fetch("Applexecution_#{id}", :expires_in => 1.minutes) { self.find(id) }
  end

end
