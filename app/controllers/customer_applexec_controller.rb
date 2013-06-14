# encoding: utf-8
class CustomerApplexecController < ApplicationController

  @@applicationAnnotations = {}  # Anmerkungen zu Appications als Hash mit ID_Application als Schlüssel

  @@appNoteFileName = "applicationAnnotation.serialized"

private
  def checkAndLoad_applicationAnnotations
    if @@applicationAnnotations.length == 0    # Hash noch leer (nicht geladen)
      File.open(@@appNoteFileName) do |f|
        @@applicationAnnotations = Marshal.load(f)
      end
    end
    rescue Exception => ex; @@applicationAnnotations = {}
  end
  
  def save_applicationAnnotations
    File.open(@@appNoteFileName, "w+") do |f|
      Marshal.dump(@@applicationAnnotations, f)
    end
  end  

public
  # Einstieg in Seite
  def laufzeiten
    @whtransferdates = Whtransferdate.all :conditions => "startprocessing>SYSDATE-50",
      :include => [:processingday, :whtransfertype],
      :order => "startprocessing DESC"
    @applcategories = Applcategory.all :order=>"id"
    developmentteam0 = Developmentteam.new(:name=>"[Alle Teams]")
    developmentteam0.id = 0
    @developmentteams = [developmentteam0]
    Developmentteam.all(:order=>"id").each do |d|
      @developmentteams << d
    end
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial => "customer_applexec/laufzeiten"}');"}
    end
  end
  
  def show_applexec_per_whtransferdate
    checkAndLoad_applicationAnnotations    # Lade zusätzliche Attribute
    @applicationAnnotations = @@applicationAnnotations # Merken der Instanzvariable für Verwendung im View
    @whtransferdate = Whtransferdate.find  params[:whtransferdate][:id],
      :include => [:whtransfertype, :processingday]
    id_applcategory = params[:applcategory][:id].to_i
    id_developmentteam = params[:developmentteam][:id].to_i
    conditionstring="id_whtransferdate=?"
    conditionvalues = [@whtransferdate.id]
    unless id_applcategory == 0   # Nicht alle Kategorien ausgewaehlt
      conditionstring += " AND ID_ApplCategory=?"
      conditionvalues << id_applcategory
    end
    unless id_developmentteam == 0   # Nicht alle Teams ausgewaehlt
      conditionstring += " AND Application.id_developmentteam=?"
      conditionvalues << id_developmentteam
    end

    @legacyapplexecutions = sql_select_all ["
        SELECT /* Panorama-Tool Ramm */
               ae.ID,
               ae.ID_Application,
               ast.Name           Status_Name,
               a.Name             Application_Name,
               a.Description      Application_Description,
               ae.TotalNrOfItems,
               ae.ExecutionStart,
               ae.ExecutionEnd
        FROM   sysp.LegacyApplExecution ae
        JOIN   sysp.ApplExecutionStatus ast ON ast.ID = ae.ID_ApplExecutionStatus
        JOIN   sysp.Application a          ON a.ID = ae.ID_Application
        WHERE  #{conditionstring}
        ORDER BY executionend-executionstart DESC
        "].concat conditionvalues

    # Laufzeit summieren total
    @runtimeTotal = 0
    @executionCountTotal=0
    # Kleinstes Start und groesstes Endedatum finden  
    @legacyapplexecutions.each do |la|
      if la.executionend && la.executionstart && la.id_application != 128 && la.id_application != 120
        runtimeLocal = la.executionend-la.executionstart
      else
        runtimeLocal = 0
      end
      @runtimeTotal += runtimeLocal
      @executionCountTotal += 1
    end

    respond_to do |format|
      format.js {render :js => "$('#applexecutions').html('#{j render_to_string :partial=>'show_applexec_per_whtransferdate'}');"}
    end
  end
  
  def show_applexec_details
    @legacyapplexecution = sql_select_first_row ["SELECT l.*,
                                                        s.Name ApplExecutionStatusName,
                                                        a.COName ApplicationCOName,
                                                        a.PLSQLPackage ApplicationPLSQLPackage,
                                                        a.Name          ApplicationName
                                                  FROM sysp.Legacyapplexecution l
                                                  JOIN   sysp.Application a ON a.ID = l.ID_Application
                                                  JOIN   sysp.ApplExecutionStatus s ON s.ID = l.ID_ApplExecutionStatus
                                                  WHERE l.ID=?", params[:id_applexecution] ]
    @legacyapplexecutions = sql_select_all ["SELECT l.*,
                                                    s.Name          ApplExecutionStatusName,
                                                    a.COName        ApplicationCOName,
                                                    a.PLSQLPackage  ApplicationPLSQLPackage,
                                                    a.Name          ApplicationName
                                             FROM   sysp.Legacyapplexecution l
                                             JOIN   sysp.Application a ON a.ID = l.ID_Application
                                             JOIN   sysp.ApplExecutionStatus s ON s.ID = l.ID_ApplExecutionStatus
                                             WHERE  id_application=?
                                             AND    executionstart > SYSDATE-300
                                             ORDER BY executionstart DESC", @legacyapplexecution.id_application ]
    #  :include => [:applexecutionstatus, :application, :whtransferdate],
    @applattrs = Applattr.all :conditions=>["ID_Application=?",@legacyapplexecution.id_application], :include=>[:gaattr]
    
    respond_to do |format|
      format.js {render :js => "$('#applexec_details').html('#{j render_to_string :partial=>'show_applexec_details'}');
                                $('#applexec_history').html('#{j render_to_string :partial=>'show_applexec_history'}');
                "}
    end
  end
  
  # Speichern Anmerkungen einer Application aus Parametern
  def saveAnnotation
    checkAndLoad_applicationAnnotations    # Lade zusätzliche Attribute
    id_application = params[:id_application]
    annotation = {}
    annotation[:state]      = params[:state]
    annotation[:state] = "ungepr." if annotation[:state] == ""  # Verhindern Leerstring, über den nicht gelinkt werden kann
    annotation[:employee]   = params[:employee]
    annotation[:changetime] = Time.now.strftime("%d.%m.%Y %H:%M:%S") 
    annotation[:note]        = params[:note]
    @@applicationAnnotations[params[:id_application]] = annotation
    save_applicationAnnotations   # Speichern in File
    respond_to do |format|
      format.js {render :js => "$('#applexec_history').html('#{j render_to_string :partial=>'change_state_succeeded'}');"}
    end
  end
  
end
