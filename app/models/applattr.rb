class Applattr < ActiveRecord::Base
  self.table_name = "sysp.applattr"
  belongs_to :gaattr,    :foreign_key => "id_gaattr"
end
