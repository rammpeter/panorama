class Ofbulkgroup < ActiveRecord::Base
  self.table_name =  "JOURNAL.OFBULKGROUP"
  
  belongs_to :ofmessagetype,   :foreign_key => "id_ofmessagetype"

end
