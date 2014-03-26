# encoding: utf-8
class OnlineFrameworkController < ApplicationController

  def show_overview
    # Pruefen auf Blocker-Status
    @blocker_count = sql_select_one "\
      SELECT /* NOA-Tools Ramm */ 
             CASE WHEN (MaxHeartBeatInterval - TRUNC((SYSDATE - HeartBeatTimestamp) * 24 * 60 * 60)) >= 0
             THEN 1 ELSE 0 END
      FROM  sysp.ApplicationHeartBeat
      WHERE ID_Application  = 1256
      AND   YN_CheckEnabled = 'Y'"

    # Test auf Messsages in Notfall-DB
    @dbLinkCount = sql_select_one "SELECT /* Panorama-Tool Ramm */ Count(*) FROM User_DB_Links WHERE DB_Link='NOAFB' OR SUBSTR(DB_Link,1,INSTR(DB_Link,'.')-1)='NOAFB'"
    if @dbLinkCount.to_i > 0  # DB-Link existiert
      begin
        @messageCountNOAFB = sql_select_one "SELECT /* NOA-Tools Ramm */ Count(*) FROM journal.OFMessage@NOAFB"
      rescue Exception
        @messageCountNOAFB = nil  # Nicht ermittelbar
      end
    else
      @messageCountNOAFB = nil  # Nicht ermittelbar
    end

    @error_count_exceeded = sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             ID_OFMessageType
      FROM   (SELECT mt.ID ID_OFMessageType, mt.MessageCountErrorLimitAlert,
                     (SELECT /*+ INDEX(m) */ Count(*) FROM journal.OFMessage m
                      WHERE m.YN_Erroneous = 'Y' AND m.ID_OFMessageType = mt.ID
                     ) errors
              FROM   sysp.OFMessageType mt
             )
      WHERE  errors >= MessageCountErrorLimitAlert"

    @sla_warning_exceeded = sql_select_all "\
      SELECT TO_NUMBER(SubKey) ID_OFMessageType
      FROM   sysp.OnlineAspect
      WHERE  ID_GAAttr      = 7402
      AND    ID_Application = 1343
      AND    Minute > (SELECT MAX(Minute) FROM sysp.OnlineAspect WHERE ID_GAAttr = 6216 AND ID_Application = 1343) - 60"  # Letzte 60 Sekunden seit letzter Incoming-Meldung

    @sla_alert_exceeded = sql_select_all "\
      SELECT TO_NUMBER(SubKey) ID_OFMessageType
      FROM   sysp.OnlineAspect
      WHERE  ID_GAAttr      = 7403
      AND    ID_Application = 1343
      AND    Minute > (SELECT MAX(Minute) FROM sysp.OnlineAspect WHERE ID_GAAttr = 6216 AND ID_Application = 1343) - 60"  # Letzte 60 Sekunden seit letzter Incoming-Meldung


    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "online_framework/show_overview" }');"}
    end
  end

  def list_quick_overview
    @sysdate = Time.new

    ofmsgs = sql_select_all "\
      SELECT /*+ INDEX(M) */
             m.ID_OFMessageType,
             COUNT(*) Anzahl,
             MAX(CalculatedPriority) MaxPrio,
             MIN(CalculatedPriority) MINPrio,
             'N' Erroneous
      FROM   journal.OFMessage m
      WHERE  YN_Erroneous = 'N'
      GROUP BY m.ID_OFMessageType
      UNION ALL
      SELECT /*+ INDEX(M) */
             m.ID_OFMessageType,
             COUNT(*) Anzahl,
             MAX(CalculatedPriority) MaxPrio,
             MIN(CalculatedPriority) MINPrio,
             'Y' Erroneous
      FROM   journal.OFMessage m
      WHERE  YN_Erroneous = 'Y'
      GROUP BY m.ID_OFMessageType
      ORDER BY 3, 2
    "

    msgsums = {}
    ofmsgs.each do |m|
      msgsums[m.id_ofmessagetype] = {"id_ofmessagetype" => m.id_ofmessagetype,
                                     "total"            => 0,
                                     "working"          => 0,
                                     "erroneous"        => 0,
                                     "maxprio"          => nil,
                                     "minprio"          => nil,
                                     "bulkgroups"       => 0,
                                     "minbulkgroupprio" => nil,
                                     "minbulkgroupcreationts" => nil,
                                     "activebulkgroups" => 0
      } unless msgsums[m.id_ofmessagetype]   # leeren Hash errichten initial
      msgsums[m.id_ofmessagetype]["total"]     += m.anzahl
      if m.erroneous == 'Y'
        msgsums[m.id_ofmessagetype]["erroneous"]  = m.anzahl
      else
        msgsums[m.id_ofmessagetype]["working"]  = m.anzahl
        msgsums[m.id_ofmessagetype]["maxprio"]  = m.maxprio
        msgsums[m.id_ofmessagetype]["minprio"]  = m.minprio
      end
    end

    bulkgroups = sql_select_all "\
      SELECT /*+ NO_MERGE */
             ID_OFMessageType,
             Count(*) BulkGroups,
             MIN(CalculatedPriority) MinBulkGroupPrio,
             MIN(CreationTimestamp) MinBulkGroupCreationTS,
             COUNT(ProcessStart) ActiveBulkGroups
      FROM   journal.OFBulkGroup b
      GROUP BY ID_OFMessageType
    "
    bulkgroups.each do |b|
      msgsums[b.id_ofmessagetype] = {"id_ofmessagetype" => b.id_ofmessagetype,
                                     "total"            => 0,
                                     "working"          => 0,
                                     "erroneous"        => 0,
                                     "maxprio"          => nil,
                                     "minprio"          => nil
      } unless msgsums[b.id_ofmessagetype]   # leeren Hash errichten initial
      msgsums[b.id_ofmessagetype]["bulkgroups"]              = b.bulkgroups
      msgsums[b.id_ofmessagetype]["minbulkgroupprio"]        = b.minbulkgroupprio
      msgsums[b.id_ofmessagetype]["minbulkgroupcreationts"]  = b.minbulkgroupcreationts
      msgsums[b.id_ofmessagetype]["activebulkgroups"]        = b.activebulkgroups
    end

    @msgsums = []
    msgsums.each do |key, value|
      value.extend SelectHashHelper
      @msgsums << value
    end

    render_partial
  end
  
  def list_overview
    @sysdate = Time.new
    @showApplExec = params[:showApplExec]=="1"
    fullscan_switch_limit = 500000    # Nach dieses Anzahl Records wird auf Fullscan auf OFMessage gewechselt
    fullscan = sql_select_one(["\
                           SELECT /*+ INDEX(m) */ COUNT(*) FROM journal.OFMessage WHERE RowNum<=?", fullscan_switch_limit]) == fullscan_switch_limit
       
    @msgsums = sql_select_all("\
      SELECT /*+ NOA-Tools Ramm */
             m.Total, TotalWithRunCount0, 
             m.ID_OFMessageType,                                                                 
             #{@showApplExec ? "ID_ApplExecution, ae.ID_Application, \
                                (SELECT Name FROM sysp.Application a WHERE a.ID=ae.ID_Application) ApplName, " : ""}
             m.MinCTSNoError,
             m.MinCTSError,
             m.SLA_Warning_Count, m.SLA_Alert_Count,
             m.MaxCTS,                                    
             m.MaxRunCount,                                                                       
             m.Suspended,
             m.WaitForBlocker,                                                                    
             m.WaitForWorker ,                                                                    
             m.Erroneous,                                                                         
             b.BulkGroups,
             b.MinBulkGroupPrio,
             b.MinBulkGroupCreationTS,
             m.MinCalculatedPriority,
             b.ActiveBulkGroups
      FROM                                                                                        
       (SELECT /*+ #{fullscan ? "PARALLEL(m,2) FULL(m)" : "INDEX(m)"} */
             Count(*) Total,                                                                      
             SUM(DECODE(RunCount, 0, 1, 0))                          TotalWithRunCount0,
             ID_OFMessageType, #{@showApplExec ? "ID_ApplExecution," : ""}
             MIN(DECODE(YN_Erroneous, 'N', CreationTimestamp, NULL)) MinCTSNoError,                                                 
             MIN(DECODE(YN_Erroneous, 'Y', CreationTimestamp, NULL)) MinCTSError,
             SUM(CASE WHEN YN_Erroneous='N' AND CreationTimestamp < SYSDATE-mt.WaitLimitWarning/1440 THEN 1
                 ELSE 0 END)                                         sla_warning_count,
             SUM(CASE WHEN YN_Erroneous='N' AND CreationTimestamp < SYSDATE-mt.WaitLimitAlert/1440 THEN 1
                 ELSE 0 END)                                         sla_alert_count,
             MIN(CalculatedPriority)                                 MinCalculatedPriority,
             MAX(CreationTimestamp)                                  MaxCTS,
             MAX(RunCount)                                           MaxRunCount,
             SUM(CASE WHEN YN_Erroneous='N' 
                 AND ID_OFBulkGroup IS NULL 
                 AND CalculatedPriority < SYSDATE
                 THEN 1 ELSE 0 END)                                  WaitForBlocker,
             SUM(CASE WHEN YN_Erroneous='N' 
                 AND ID_OFBulkGroup IS NULL 
                 AND CalculatedPriority >= SYSDATE
                 THEN 1 ELSE 0 END)                                  Suspended,
             SUM(DECODE(YN_Erroneous,'N', DECODE(ID_OFBulkGroup, NULL, 0,1), 0)) WaitForWorker,  
             SUM(DECODE(YN_Erroneous,'Y', 1, 0))                     Erroneous
        FROM journal.OFMessage m
        JOIN sysp.OFMessageType mt ON mt.ID = m.ID_OFMessageType
        GROUP BY ID_OFMessageType #{@showApplExec ? ",ID_ApplExecution" : ""}
       ) m
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ID_OFMessageType, Count(*) BulkGroups, MIN(CalculatedPriority) MinBulkGroupPrio,
                              MIN(CreationTimestamp) MinBulkGroupCreationTS,
                              COUNT(ProcessStart) ActiveBulkGroups
                       FROM   journal.OFBulkGroup b
                       GROUP BY ID_OFMessageType
                      ) b ON b.ID_OFMessagetype = m.ID_OFMessageType
       #{@showApplExec ? "LEFT OUTER JOIN sysp.ApplExecution ae ON ae.ID = m.ID_ApplExecution" : ""}
      ORDER BY m.MinCalculatedPriority")
    render_partial
  end

private
  # Ermitteln der Queue-Länge zu Beginn des Betrahctungszeitraumes zum Abfakturieren
  def get_start_queue_length(id_ofmessagetype, time_selection_end)
    wherestring = ""
    innerwherestring = ""
    wherefilter = []
    if id_ofmessagetype
      wherestring << " WHERE YN_Erroneous = 'N' AND ID_OFMessageType = ? "
      innerwherestring << " AND TO_NUMBER(SubKey) = ? "
      wherefilter << id_ofmessagetype
      wherefilter << id_ofmessagetype
    end
    wherefilter << time_selection_end
    (sql_select_all ["\
      SELECT (SELECT Count(*)
              FROM journal.OFMessage
              #{wherestring}
             )
              +
             (SELECT NVL(-SUM(DECODE(ID_GAAttr,4532, Counter, 0)) /* Incoming */
                     +SUM(DECODE(ID_GAAttr,6216, Counter, 0)) /* FirstTrySuccess */
                     +SUM(DECODE(ID_GAAttr,6217, Counter, 0)) /* RetrySuccess */
                     +SUM(DECODE(ID_GAAttr,6218, Counter, 0)) /* FinalError */
                     ,0)
              FROM   sysp.OnlineAspect
              WHERE ID_Application     = 1343 /* Online-Framework */
              AND   ID_GAAttr IN (4532, 6216, 6217, 6218)
              #{innerwherestring}
              AND   Minute > sysp.OnlineMonitoring.Get_Minute_From_Date(TO_TIMESTAMP(?,'#{sql_datetime_minute_mask}'))
             ) Anzahl
      FROM DUAL
      "
      ].concat(wherefilter))[0].anzahl.to_i
  end

  def get_messagetype_history_data(id_ofmessagetype, timeslice, time_selection_start, time_selection_end, instance)
    @start_queue_length = get_start_queue_length(id_ofmessagetype, time_selection_end)

    @history = sql_select_all ["\
       SELECT /* NOA-Tools Ramm */
              sysp.OnlineMonitoring.get_Date(Minute-MOD(Minute,#{timeslice})) Timestamp,
              Minute-MOD(Minute,#{timeslice})        StartMinute,
              SUM(DECODE(ID_GAAttr,4532, Counter, 0)) Incoming,
              SUM(DECODE(ID_GAAttr,6216, Counter, 0)) FirstTrySuccess,
              SUM(DECODE(ID_GAAttr,6217, Counter, 0)) RetrySuccess,
              SUM(DECODE(ID_GAAttr,6218, Counter, 0)) FinalError,
              SUM(DECODE(ID_GAAttr,6279, Counter, 0)) DivideAndConquer,
              SUM(DECODE(ID_GAAttr,6280, Counter, 0)) RetryTx,
              SUM(DECODE(ID_GAAttr,6281, Counter, 0)) FirstTry,
              SUM(DECODE(ID_GAAttr,6282, Counter, 0)) Retries,
              SUM(DECODE(ID_GAAttr,6283, Counter, 0)) FirstTryError,
              SUM(DECODE(ID_GAAttr,6284, Counter, 0)) RetryError,
              SUM(DECODE(ID_GAAttr,7251, Counter, 0)) ElapsedMilliSeconds,
              SUM(DECODE(ID_GAAttr,7862, Counter, 0)) BulkGroups
       FROM sysp.OnlineAspect
       WHERE ID_Application     = 1343 /* Online-Framework */
       AND   ID_GAAttr IN (4532, 6216, 6217, 6218, 6279, 6280, 6281, 6283, 6283, 6284, 7251, 7862)
       AND   TO_NUMBER(SubKey)  = ?
       AND   Minute >= sysp.OnlineMonitoring.Get_Minute_From_Date(TO_TIMESTAMP(?,'#{sql_datetime_minute_mask}'))
       AND   Minute <= sysp.OnlineMonitoring.Get_Minute_From_Date(TO_TIMESTAMP(?,'#{sql_datetime_minute_mask}'))
       #{' AND RACInstanceID='+instance.to_s+' ' if instance}
       GROUP BY Minute-MOD(Minute,#{timeslice})
       ORDER BY 1 DESC",
      id_ofmessagetype, time_selection_start, time_selection_end]
  end

public
  def show_msgtype_details
    @ofmessagetype = Ofmessagetype.find params[:id_ofmessagetype]
    save_session_time_selection
    @timeSlice = params[:timeSlice]
    @update_area = params[:update_area]
    @instance   = prepare_param_instance

    # Fuellen der Variablen und Listen
    get_messagetype_history_data(@ofmessagetype.id, @timeSlice, @time_selection_start, @time_selection_end, @instance)

    respond_to do |format|
      format.js {render :js => "$('##{@update_area}').html('#{j render_to_string :partial=>"list_message_details" }');"}
    end
  end

  # Anzeige der Liste der Message-Details
  def show_msgtype_details_inner
    @ofmessagetype = Ofmessagetype.find params[:id_ofmessagetype]
    save_session_time_selection
    @timeSlice = params[:timeSlice]
    @update_area = params[:update_area]
    @instance   = prepare_param_instance

    # Fuellen der Variablen und Listen
    get_messagetype_history_data(@ofmessagetype.id, @timeSlice, @time_selection_start, @time_selection_end, @instance)

    respond_to do |format|
      format.js {render :js => "$('##{@update_area}').html('#{j render_to_string :partial=>"list_message_details_inner" }');"}
    end
  end


  # Anzeige der Details eines Timeslice nach Message-Typen
  def show_timeslice_details
    @startMinute = params[:startMinute].to_i
    @timeSlice = params[:timeSlice].to_i
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @id_domain = params[:id_domain].to_i
    @update_area = params[:update_area]
    @instance   = prepare_param_instance

    @history  = sql_select_all ["\ 
       SELECT /* NOA-Tools Ramm */ 
              TO_NUMBER(SubKey)                       ID_OFMessageType,      
              (SELECT Name FROM sysp.OFMessageType WHERE ID=TO_NUMBER(SubKey) ) MsgTypeName,
              SUM(DECODE(ID_GAAttr,4532, Counter, 0)) Incoming,              
              SUM(DECODE(ID_GAAttr,6216, Counter, 0)) FirstTrySuccess,       
              SUM(DECODE(ID_GAAttr,6217, Counter, 0)) RetrySuccess,          
              SUM(DECODE(ID_GAAttr,6218, Counter, 0)) FinalError,            
              SUM(DECODE(ID_GAAttr,6279, Counter, 0)) DivideAndConquer,      
              SUM(DECODE(ID_GAAttr,6280, Counter, 0)) RetryTx,               
              SUM(DECODE(ID_GAAttr,6281, Counter, 0)) FirstTry,              
              SUM(DECODE(ID_GAAttr,6282, Counter, 0)) Retries,               
              SUM(DECODE(ID_GAAttr,6283, Counter, 0)) FirstTryError,         
              SUM(DECODE(ID_GAAttr,6284, Counter, 0)) RetryError,             
              SUM(DECODE(ID_GAAttr,7251, Counter, 0)) ElapsedMilliSeconds,
              SUM(DECODE(ID_GAAttr,7862, Counter, 0)) BulkGroups
       FROM sysp.OnlineAspect                                                
       WHERE ID_Application     = 1343 /* Online-Framework */                
       AND   ID_GAAttr IN (4532, 6216, 6217, 6218, 6279, 6280, 6281, 6283, 6283, 6284, 7251, 7862)
       AND   Minute             >= ?                                         
       AND   Minute             < ?                                          
       #{' AND RACInstanceID='+@instance.to_s+' ' if @instance}
       #{(@id_domain && @id_domain!=0) ? 
         " AND TO_NUMBER(SubKey) IN (SELECT ID FROM sysp.OFMessageType WHERE ID_Domain="+@id_domain.to_s+")" : 
         ""}
       GROUP BY SubKey                                                          
       ORDER BY 1 DESC",   
      @startMinute, @startMinute+@timeSlice]
    
    
    @startTimestamp = sql_select_all(["SELECT sysp.OnlineMonitoring.get_Date(?) ts FROM DUAL", 
                                              @startMinute])[0].ts
    respond_to do |format|
      format.js {render :js => "$('##{@update_area}').html('#{j render_to_string :partial=>"list_timeslice_details" }');"}
    end
  end

  # Noch genutzt?
  def show_history
    # Domain-Liste für Auswahl
    da = Domain.new(:name=> "[Alle]")
    da.id = 0  # alias für Alle
    @domains = []
    @domains << da
    Domain.all.each do |d|
      @domains << d
    end
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "online_framework/show_history" }');"}
    end
  end

  def show_history_list
    @showGroup = params[:ShowGroup]
    @timeSlice = params[:timeSlice]
    @id_domain = params[:domain][:id].to_i
    @show_rac  = params[:show_rac] == '1'
    save_session_time_selection   # werte in session puffern


    case @showGroup
      when "ID_OFMessageType" then
        col1_stmt = "TO_NUMBER(SubKey) ID_OFMessageType"
      when "TimeSlice" then
        col1_stmt = "sysp.OnlineMonitoring.Get_Date(Minute-MOD(Minute,#{@timeSlice})) Timestamp,"+
                "Minute-MOD(Minute,#{@timeSlice}) StartMinute"
        @start_queue_length = get_start_queue_length(nil, @time_selection_end)
      else col1_stmt = "[Unknown]"
    end
    @history  = sql_select_all ["\ 
       SELECT /* NOA-Tools Ramm */ " + col1_stmt + ",                                                              
              SUM(DECODE(ID_GAAttr,4532, Counter, 0)) Incoming,
              #{(@show_rac ? "RACInstanceID," : "")}
              SUM(DECODE(ID_GAAttr,6216, Counter, 0)) FirstTrySuccess,       
              SUM(DECODE(ID_GAAttr,6217, Counter, 0)) RetrySuccess,          
              SUM(DECODE(ID_GAAttr,6218, Counter, 0)) FinalError,            
              SUM(DECODE(ID_GAAttr,6279, Counter, 0)) DivideAndConquer,      
              SUM(DECODE(ID_GAAttr,6280, Counter, 0)) RetryTx,               
              SUM(DECODE(ID_GAAttr,6281, Counter, 0)) FirstTry,              
              SUM(DECODE(ID_GAAttr,6282, Counter, 0)) Retries,               
              SUM(DECODE(ID_GAAttr,6283, Counter, 0)) FirstTryError,         
              SUM(DECODE(ID_GAAttr,6284, Counter, 0)) RetryError,             
              SUM(DECODE(ID_GAAttr,7251, Counter, 0)) ElapsedMilliSeconds,
              SUM(DECODE(ID_GAAttr,7862, Counter, 0)) BulkGroups
             FROM sysp.OnlineAspect                                     
             WHERE ID_Application     = 1343 /* Online-Framework */     
             AND   ID_GAAttr IN (4532, 6216, 6217, 6218, 6279, 6280, 6281, 6283, 6283, 6284, 7251, 7862)
             AND   Minute >= sysp.OnlineMonitoring.Get_Minute_From_Date(TO_TIMESTAMP(?,'#{sql_datetime_minute_mask}'))
             AND   Minute <= sysp.OnlineMonitoring.Get_Minute_From_Date(TO_TIMESTAMP(?,'#{sql_datetime_minute_mask}'))
            #{(@id_domain && @id_domain!=0) ? 
              " AND TO_NUMBER(SubKey) IN (SELECT ID FROM sysp.OFMessageType WHERE ID_Domain="+@id_domain.to_s+")" :
              ""}
            GROUP BY " +
      case @showGroup
              when "ID_OFMessageType" then "TO_NUMBER(SubKey)"
              when "TimeSlice"       then  "Minute-MOD(Minute,#{@timeSlice})"
        else "[Unknown]"
      end + (@show_rac ? ", RACInstanceID" : "") +
       " ORDER BY 1 " +
      case @showGroup
          when "ID_OFMessageType" then ""
          when "TimeSlice"        then "DESC"
        else "[Unknown]"
       end+(@show_rac ? ", RACInstanceID" : ""),
       @time_selection_start, @time_selection_end ]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=> "list_history" }');"}
    end
  end

  # Anzeige Fehlermeldungen
  # Kann mit verschiedenen Filtern aufgerufen werden
  # - ID_OFErrorMessage
  # - StartZeitpunkt + Scheibe
  def show_oferrormessage
    @id_ofmessagetype  = params[:id_ofmessagetype].to_i   # NIL wird zu 0
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @timeSlice         = params[:timeSlice].to_i
    @update_area        = params[:update_area]
    @maxErrors         = params[:maxErrors]

    @maxErrors = 5 unless @maxErrors  # Default
    
    stmt = "\ 
       SELECT /* NOA-Tools Ramm */ 
              em.ID_OFMessage,
              em.CreationTimestamp,
              em.ErrorMessage,
              em.ID_Exception,
              m.ID_OFMessageType,
              m.CreationTimestamp MsgCreationTimestamp,
              (SELECT Name FROM sysp.OFMessageType mt WHERE mt.ID=m.ID_OFMessageType) MsgTypeName,
              (SELECT Name FROM sysp.Exception ex WHERE ex.ID=em.ID_Exception) ExName
       FROM   journal.OFErrorMessage em,
              journal.OFMessage      m
       WHERE  em.ID_OFMessage = m.ID
       AND    RowNum          <= ?"
    
    stmt_params = [stmt, @maxErrors]
    
    if @id_ofmessagetype != 0
      stmt << " AND m.ID_OFMessageType=? "
      stmt_params << @id_ofmessagetype
    end
    if @time_selection_start
      stmt << " AND em.CreationTimestamp>= TO_DATE(?, '#{sql_datetime_minute_mask}') "
      stmt_params << @time_selection_start
      if @time_selection_end
        stmt << " AND em.CreationTimestamp<= TO_DATE(?, '#{sql_datetime_minute_mask}') "
        stmt_params << @time_selection_end
      else            # kein time_selection_end, dann sollte timeSlice belegt sein
        if @timeSlice > 0
          stmt << "AND em.CreationTimestamp<(TO_DATE(?, '#{sql_datetime_minute_mask}') + (?/1440) )"
          stmt_params << @time_selection_start
          stmt_params << @timeSlice
        else
          raise "Weder @time_selection_end noch @timeSlice belegt"
        end
      end
    end
    @errors  = sql_select_all stmt_params
    
    respond_to do |format|
      format.js {render :js => "$('##{@update_area}').html('#{j render_to_string :partial=>"list_oferrormessage" }');"}
    end
  end
  
  def show_working_ofbulkgroup
    @bulkgroup_type_sums=sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             ID_OFMessageType,
             MIN(ID_Domain)                                         ID_Domain,
             COUNT(*)                                               Total,
             SUM(CASE WHEN ProcessStart IS NULL THEN 1 ELSE 0 END)  Waiting,
             SUM(CASE WHEN ProcessStart IS NULL THEN 0 ELSE 1 END)  Working,
             MIN(CreationTimeStamp)                                 MinCreation,
             MAX(CreationTimeStamp)                                 MaxCreation,
             MAX(CalculatedPriority)                                MinPrio,
             MIN(CalculatedPriority)                                MaxPrio,
             MAX((SYSDATE-CreationTimestamp)*(1440*60))             MaxAge
      FROM   journal.OFBulkGroup
      GROUP BY ID_OFMessageType
      ORDER BY SUM(CASE WHEN ProcessStart IS NULL THEN 0 ELSE 1 END)  DESC
      "
    @bulkgroup_domain_sums=sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             ID_Domain,
             COUNT(*)                                               Total,
             SUM(CASE WHEN ProcessStart IS NULL THEN 1 ELSE 0 END)  Waiting,
             SUM(CASE WHEN ProcessStart IS NULL THEN 0 ELSE 1 END)  Working,
             MIN(CreationTimeStamp)                                 MinCreation,
             MAX(CreationTimeStamp)                                 MaxCreation,
             MAX(CalculatedPriority)                                MinPrio,
             MIN(CalculatedPriority)                                MaxPrio,
             MAX((SYSDATE-CreationTimestamp)*(1440*60))             MaxAge
      FROM   journal.OFBulkGroup
      GROUP BY ID_Domain
      ORDER BY SUM(CASE WHEN ProcessStart IS NULL THEN 0 ELSE 1 END)  DESC
      "



    @bulkgroups=sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             bg.ID,
             bg.CreationTimestamp,
             bg.ID_OFMessageType,
             bg.CalculatedPriority,
             (SELECT Count(*) FROM journal.OFMessage m WHERE m.ID_OFBulkGroup = bg.ID) Messages,
             (SYSDATE-bg.CreationTimestamp)*(1440*60) Age_Secs,
             bg.ProcessStart,
             (SYSDATE-bg.ProcessStart)*(1440*60) In_Process_Secs
      FROM   journal.OFBulkGroup bg
      WHERE  bg.ProcessStart IS NOT NULL
      "
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "online_framework/show_working_ofbulkgroup" }');"}
    end
  end


  def show_external_queue
    @content = sql_select_all "\
      SELECT /* Panorama-Tool Ramm */ ID_OFMessageType, MIN(CreationTimestamp) MinTS, MAX(CreationTimestamp) MaxTS, COUNT(*) Anzahl,
             (SELECT Name FROM sysp.OFMessageType mt WHERE mt.ID = m.ID_OFMessageType) Name
      FROM   journal.OFExtServiceMessage m
      GROUP BY ID_OFMessageType
      ORDER BY 2"

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "online_framework/show_external_queue" }');"}
    end
  end
end


