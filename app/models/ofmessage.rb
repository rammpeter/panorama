class Ofmessage < ActiveRecord::Base
  self.table_name =  "JOURNAL.OFMESSAGE"
  #belongs_to :ofmessagetype,    :foreign_key => "id_ofmessagetype"

  def ofmessagetype
    Ofmessagetype.get_cached_instance(self.id_ofmessagetype, session[:database].hash)
  end

end
