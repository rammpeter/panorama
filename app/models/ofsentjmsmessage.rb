class Ofsentjmsmessage < ActiveRecord::Base
  self.table_name = "JOURNAL.OFSENTJMSMESSAGE"
  belongs_to :ofmessagetype,    :foreign_key => "id_ofmessagetype"

end
