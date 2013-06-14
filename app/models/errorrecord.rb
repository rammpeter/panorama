class Errorrecord < ActiveRecord::Base
  self.table_name =  "sysp.errorrecord"
  belongs_to :errorclass,    :foreign_key => "id_errorclass"
  belongs_to :errorstatus,   :foreign_key => "id_errorstatus"
  belongs_to :errorseverity, :foreign_key => "id_errorseverity"
  
  # Lieferung der zusammengehörigen Businessdata-Records
  def businessdata
    bd_records = Errrecbusinessdata.all :conditions=>["ID_ErrorRecord=?", self.id],
      :order => "SerialNo"
    result = ""      
    bd_records.each do |bd|
      result = result + bd.businessdata 
    end
    result
  end
  
end
