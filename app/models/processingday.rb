class Processingday < ActiveRecord::Base
  self.table_name =  "sysp.processingday"
  
  # Anzeigezeile für Comboboxen etc.
  def list_line
    self.day.to_datetime.strftime("%d.%m.%Y")
  end
  
end
