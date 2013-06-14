class Whtransferdate < ActiveRecord::Base
  self.table_name =  "sysp.whtransferdate"
  belongs_to :processingday,    :foreign_key => "id_processingday"
  belongs_to :whtransfertype,   :foreign_key => "id_whtransfertype"
  
  def selectlist_entry
    self.processingday.day.to_datetime.strftime("%d.%m.%Y")+" - "+
    self.whtransfertype.name+" - "+
    self.startprocessing.to_datetime.strftime("%d.%m.%Y %H:%M:%S")+
    " - Billingsystem="+self.id_billingsystem.to_s+
    " - ID="+self.id.to_s
  end
end
