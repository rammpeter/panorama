class Errrecbusinessdata < ActiveRecord::Base
  self.table_name =  "SYSP.ERRRECBUSINESSDATA"
  belongs_to :errorrecord,    :foreign_key => "id_errorrecord"
end
