class Company  < ActiveRecord::Base
  self.table_name =  "sysp.company"
  
  def list_name
    "#{self.id}#{self.id ? ": " : ""}#{self.name}"
  end
  
end