class Gaattr < ActiveRecord::Base
  self.table_name =  "sysp.gaattr"
  
  def self.finds (*args)
    superclass.first
  end
  
end


