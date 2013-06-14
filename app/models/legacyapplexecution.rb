class Legacyapplexecution < ActiveRecord::Base
  self.table_name =  "sysp.legacyapplexecution"
  belongs_to :application,    :foreign_key => "id_application", :class_name=>"SyspApplication"
  belongs_to :applexecutionstatus, :foreign_key => "id_applexecutionstatus"
  belongs_to :whtransferdate,    :foreign_key => "id_whtransferdate"

# Konvertieren von als Date gelesenen ganzzahligen Time-Feldern zurueck in Date

  def executionstart
    if read_attribute(:executionstart).class == Date
       read_attribute(:executionstart).to_time
    else      
       read_attribute(:executionstart)
    end
  end


  def executionend
    if read_attribute(:executionend).class == Date
       read_attribute(:executionend).to_time
    else      
       read_attribute(:executionend)
    end
  end

end
