class Importcustaccounttransaction < ActiveRecord::Base
  self.table_name =  "CUST.IMPORTCUSTACCOUNTTRANSACTION"
  
  
  belongs_to :gaattr_source, :foreign_key => "id_gaattr_source", 
    :class_name=>"Gaattr"
  
end
