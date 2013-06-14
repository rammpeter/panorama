class Applexecattr < ActiveRecord::Base
  self.table_name =  "sysp.applexecattr"
  belongs_to :gaattr,    :foreign_key => "id_gaattr"
end
