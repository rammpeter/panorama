# encoding: utf-8
# Zusatzfunktionen, die auf speziellen Tabellen und Prozessen aufsetzen, die nicht prinzipiell in DB vorhanden sind
class AdditionController < ApplicationController
  def list_db_cache_historic
    max_result_count = params[:maxResultCount]
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    save_session_time_selection                  # Werte puffern fuer spaetere Wiederverwendung

    if @show_partitions == '1'
      partition_expression = "PartitionName"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (SELECT Instance, Owner, Name, PartitionName,
                     AVG(BlocksTotal) AvgBlocksTotal,
                     MIN(BlocksTotal) MinBlocksTotal,
                     Max(BlocksTotal) MaxBlocksTotal,
                     SUM(BlocksTotal) SumBlocksTotal,
                     AVG(BlocksDirty) AvgBlocksDirty,
                     MIN(BlocksDirty) MinBlocksDirty,
                     MAX(BlocksDirty) MaxBlocksDirty,
                     COUNT(*)         Samples
              FROM   (SELECT Instance, Owner, Name, #{partition_expression} PartitionName,
                             SUM(BlocksTotal) BlocksTotal,
                             SUM(BlocksDirty) BlocksDirty
                      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
                      WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                      #{" AND Instance=#{@instance}" if @instance}
                      -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                      GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
                     )
              GROUP BY Instance, Owner, Name, PartitionName
              ORDER BY SUM(BlocksTotal) DESC
             )
      WHERE RowNum <= ?",
                              @time_selection_start, @time_selection_end, max_result_count
                             ]

    respond_to do |format|
      format.js {render :js => "$('#list_db_cache_historic_area').html('#{j render_to_string :partial=>"list_db_cache_historic" }');"}
    end
  end

  def list_db_cache_historic_detail
    @instance = prepare_param_instance
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @owner           = params[:owner]
    @name            = params[:name]
    @partitionname   = params[:partitionname]
    @show_partitions = params[:show_partitions]

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ SnapshotTS,
             SUM(BlocksTotal) BlocksTotal,
             SUM(BlocksDirty) BlocksDirty
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
      WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      AND    Owner    = ?
      AND    Name     = ?
      AND    Instance = ?
      #{" AND PartitionName = ?" if @partitionname}
      GROUP BY SnapshotTS
      ORDER BY SnapshotTS
      "].concat([@time_selection_start, @time_selection_end, @owner, @name, @instance].concat(@partitionname ? [@partitionname] : [])
                             )

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_db_cache_historic_detail" }');"}
    end
  end


  def list_db_cache_historic_snap
    @instance   = prepare_param_instance
    @snapshotts = params[:snapshotts]
    @show_partitions = params[:show_partitions]

    if @show_partitions == '1'
      partition_expression = "PartitionName"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Owner, Name, #{partition_expression} PartitionName,
             SUM(BlocksTotal) BlocksTotal,
             SUM(BlocksDirty) BlocksDirty
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects
      WHERE  SnapshotTS = TO_DATE(?, '#{sql_datetime_second_mask}')
      AND    Instance   = ?
      GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
      ORDER BY BlocksTotal DESC
      ", @snapshotts, @instance]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_db_cache_historic_snap" }');"}
    end
  end

  def list_db_cache_historic_timeline
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]

    if @show_partitions == '1'
      partition_expression = "c.PartitionName"
    else
      partition_expression = "NULL"
    end

    singles = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             c.Instance, c.SnapshotTS, c.Owner, c.Name, #{partition_expression} PartitionName, SUM(c.BlocksTotal) BlocksTotal
      FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects c
      JOIN   (
              SELECT Instance, Owner, Name, PartitionName, SumBlocksTotal
              FROM   (SELECT Instance, Owner, Name, PartitionName,
                             Max(BlocksTotal) MaxBlocksTotal,
                             SUM(BlocksTotal) SumBlocksTotal
                      FROM   (SELECT Instance, Owner, Name, #{partition_expression} PartitionName,
                                     SUM(BlocksTotal) BlocksTotal
                              FROM   #{session[:dba_hist_cache_objects_owner]}.DBA_hist_Cache_Objects c
                              WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              #{" AND Instance=#{@instance}" if @instance}
                              -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                              GROUP BY SnapshotTS, Instance, Owner, Name, #{partition_expression}
                             )
                      GROUP BY Instance, Owner, Name, PartitionName
                      ORDER BY Max(BlocksTotal) DESC
                     )
              WHERE RowNum <= 10
             ) s ON s.Instance = c.Instance AND s.Owner = c.Owner AND s.Name||s.PartitionName = c.Name||#{partition_expression}
      WHERE  c.SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      #{" AND c.Instance=#{@instance}" if @instance}
      GROUP BY c.Instance, c.SnapShotTS, c.Owner, c.Name, #{partition_expression}
      ORDER BY c.SnapshotTS, MIN(s.SumBlocksTotal) DESC
      ",
                              @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end,
                             ]

    @snapshots = []           # Result-Array
    headers={}               # Spalten
    record = {}
    singles.each do |s|     # Iteration über einzelwerte
      record[:snapshotts] = s.snapshotts unless record[:snapshotts] # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record[:snapshotts] != s.snapshotts
        @snapshots << record
        record = {}
        record[:snapshotts] = s.snapshotts
      end
      colname = "#{"(#{s.instance}) " unless @instance}#{s.owner}.#{s.name} #{"(#{s.partitionname})" if s.partitionname}"
      record[colname] = s.blockstotal
      headers[colname] = true    # Merken, dass Spalte verwendet
    end
    @snapshots << record if singles.length > 0    # Letzten Record in Array schreiben wenn Daten vorhanden

    # Alle nicht belegten Werte mit 0 initialisieren
    @snapshots.each do |s|
      headers.each do |key, value|              # Initialisieren aller Werte zum Zeitpunkt mit 0, falls kein Sample existiert
        s[key] = 0 unless s[key]
      end
    end



    # JavaScript-Array aufbauen mit Daten
    output = ""
    output << "jQuery(function($){"
    output << "var data_array = ["
    headers.each do |key, value|
      output << "  { label: '#{key}',"
      output << "    data: ["
      @snapshots.each do |s|
        output << "[#{milliSec1970(s[:snapshotts])}, #{s[key]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    diagram_caption = "Top 10 Objekte im DB-Cache von #{@time_selection_start} bis #{@time_selection_end} #{"Instance=#{@instance}" if @instance}"

    plot_area_id = "plot_area_#{session[:request_counter]}"
    output << "plot_diagram('#{session[:request_counter]}', '#{plot_area_id}', '#{diagram_caption}', data_array, false, true, true);"
    output << "});"

    html="<div id='#{plot_area_id}'></div>"
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j html}');
                                #{ output}"
      }
    end
  end # list_db_cache_historic_timeline



  private

  def blocking_locks_groupfilter_values(key)

    retval = {
        "SnapshotTS"        => {:sql => "l.snapshotTS =TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true },
        "Min_Zeitstempel"   => {:sql => "l.snapshotTS>=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
        "Max_Zeitstempel"   => {:sql => "l.snapshotTS<=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
        "Instance"          => {:sql => "l.Instance_Number" },
        "SID"               => {:sql => "l.SID"},
        "SerialNo"          => {:sql => "l.SerialNo"},
        "Hide_Non_Blocking" => {:sql => "NVL(l.Blocking_SID, '0') != ?", :already_bound => true },
        "Blocking Object"   => {:sql => "LOWER(l.Blocking_Object_Schema)||'.'||l.Blocking_Object_Name" },
        "SQL-ID"            => {:sql => "l.SQL_ID"},
        "Module"            => {:sql => "l.Module"},
        "Objectname"        => {:sql => "l.ObjectName"},
        "Locktype"          => {:sql => "l.LockType"},
        "Request"           => {:sql => "l.Request"},
        "LockMode"          => {:sql => "l.LockMode"},
        "RowID"             => {:sql => "CAST(l.blocking_rowid AS VARCHAR2(18))"},
        "B.Instance"        => {:sql => 'l.blocking_Instance_Number'},
        "B.SID"             => {:sql => 'l.blocking_SID'},
        "B.SQL-ID"          => {:sql => 'l.blocking_SQL_ID'},
    }[key]
    raise "blocking_locks_groupfilter_values: unknown key '#{key}'" unless retval
    retval
  end


  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_blocking_locks_groupfilter (groupfilter, groupkey)
    @groupfilter = groupfilter
    @groupkey    = groupkey
    @where_string  = ""                    # Filter-Text für nachfolgendes Statement mit AND-Erweiterung
    @where_values = []    # Filter-werte für nachfolgendes Statement

    @groupfilter.each {|key,value|
      sql = blocking_locks_groupfilter_values(key)[:sql].clone

      unless blocking_locks_groupfilter_values(key)[:already_bound]
        if value && value != ''
          sql << " = ?"
        else
          sql << " IS NULL"
        end
      end

      @where_string << " AND #{sql}"
      # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      @where_values << value if value && value != ''
    }

  end

  public


  def list_blocking_locks_history
    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung
    @timeslice = params[:timeslice]

    # Sprungverteiler nach diversen commit-Buttons
    list_blocking_locks_history_sum       if params[:commit_table]
    list_blocking_locks_history_hierarchy if params[:commit_hierarchy]

  end

  def list_blocking_locks_history_sum
    # Initiale Belegung des Groupfilters, wird dann immer weiter gegeben
    groupfilter = {}

    unless params[:show_non_blocking]     # non-Blocking filtern
      groupfilter = {"Hide_Non_Blocking" => '0' }
    end

    where_from_blocking_locks_groupfilter(groupfilter, nil)


    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             MIN(SnapshotTS)      Min_SnapshotTS,
             MAX(SnapshotTS)      Max_SnapshotTS,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
             COUNT(*)             Samples,
             CASE WHEN COUNT(DISTINCT Instance_Number) = 1 THEN TO_CHAR(MIN(Instance_Number)) ELSE '< '||COUNT(DISTINCT Instance_Number)||' >' END Instance_Number,
             CASE WHEN COUNT(DISTINCT SID)             = 1 THEN TO_CHAR(MIN(SID))             ELSE '< '||COUNT(DISTINCT SID)            ||' >' END SID,
             CASE WHEN COUNT(DISTINCT SQL_ID)          = 1 THEN TO_CHAR(MIN(SQL_ID))          ELSE '< '||COUNT(DISTINCT SQL_ID)         ||' >' END SQL_ID,
             CASE WHEN COUNT(DISTINCT SerialNo)        = 1 THEN TO_CHAR(MIN(SerialNo))        ELSE '< '||COUNT(DISTINCT SerialNo)       ||' >' END SerialNo,
             CASE WHEN COUNT(DISTINCT Module)          = 1 THEN TO_CHAR(MIN(Module))          ELSE '< '||COUNT(DISTINCT Module)         ||' >' END Module,
             CASE WHEN COUNT(DISTINCT Objectname)      = 1 THEN TO_CHAR(MIN(ObjectName))      ELSE '< '||COUNT(DISTINCT ObjectName)     ||' >' END ObjectName,
             CASE WHEN COUNT(DISTINCT LockType)        = 1 THEN TO_CHAR(MIN(LockType))        ELSE '< '||COUNT(DISTINCT LockType)       ||' >' END LockType,
             CASE WHEN COUNT(DISTINCT Request)         = 1 THEN TO_CHAR(MIN(Request))         ELSE '< '||COUNT(DISTINCT Request)        ||' >' END Request,
             CASE WHEN COUNT(DISTINCT LockMode)        = 1 THEN TO_CHAR(MIN(LockMode))        ELSE '< '||COUNT(DISTINCT LockMode)       ||' >' END LockMode,
             CASE WHEN COUNT(DISTINCT Blocking_Object_Schema||'.'||Blocking_Object_Name) = 1 THEN TO_CHAR(MIN(LOWER(Blocking_Object_Schema)||'.'||Blocking_Object_Name))        ELSE '< '||COUNT(DISTINCT Blocking_Object_Schema||'.'||Blocking_Object_Name)||' >' END Blocking_Object,
             CASE WHEN COUNT(DISTINCT Blocking_RowID)  = 1 THEN CAST(MIN(Blocking_RowID) AS VARCHAR2(18)) ELSE '< '||COUNT(DISTINCT Blocking_RowID) ||' >' END Blocking_RowID,
             CASE WHEN COUNT(DISTINCT Blocking_Instance_Number) = 1 THEN TO_CHAR(MIN(Blocking_Instance_Number)) ELSE '< '||COUNT(DISTINCT Blocking_Instance_Number)||' >' END Blocking_Instance_Number,
             CASE WHEN COUNT(DISTINCT Blocking_SID)    = 1 THEN TO_CHAR(MIN(Blocking_SID))    ELSE '< '||COUNT(DISTINCT Blocking_SID)   ||' >' END Blocking_SID,
             CASE WHEN COUNT(DISTINCT Blocking_SerialNo)=1 THEN TO_CHAR(MIN(Blocking_SerialNo))ELSE '< '||COUNT(DISTINCT Blocking_SerialNo)||' >' END Blocking_SerialNo,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_ID) = 1 THEN TO_CHAR(MIN(Blocking_SQL_ID)) ELSE '< '||COUNT(DISTINCT Blocking_SQL_ID)||' >' END Blocking_SQL_ID
      FROM   (SELECT l.*,
                     (TO_CHAR(SnapshotTS,'J') * 24 + TO_CHAR(SnapshotTS, 'HH24')) * 60 + TO_CHAR(SnapshotTS, 'MI') Minutes
              FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
              WHERE  SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
              #{@where_string}
             )
      GROUP BY TRUNC(Minutes/ #{@timeslice})
      ORDER BY 1",
                            @time_selection_start, @time_selection_end].concat(@where_values)

    respond_to do |format|
      format.js {render :js => "$('#list_blocking_locks_history_area').html('#{j render_to_string :partial=>"list_blocking_locks_history_sum" }');"}
    end
  end

  # Anzeige Blocker/Blocking Kaskaden, Einstiegsschirm / 1. Seite mit Root-Blockern
  def list_blocking_locks_history_hierarchy
    @locks= sql_select_all ["\
     WITH /* Panorama-Tool Ramm */
           TSSel AS (SELECT /*+ NO_MERGE */ *
                      FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
                      WHERE  l.SnapshotTS BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                      AND    l.Blocking_SID IS NOT NULL  -- keine langdauernden Locks beruecksichtigen
                      AND    l.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
                    )
      SELECT Root_SnapshotTS, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_SerialNo,
             COUNT(DISTINCT SID) Blocked_Sessions_Total,
             COUNT(DISTINCT CASE WHEN cLevel=1 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
             SUM(Seconds_In_Wait)                                      Seconds_in_wait_Total,
             CASE WHEN COUNT(DISTINCT Root_Blocking_Object_Schema||Root_Blocking_Object_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Blocking_Object_Schema||Root_Blocking_Object_Name)||' >'
             ELSE
               MIN(Root_Blocking_Object_Schema||'.'||
                 CASE
                   WHEN Root_Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                     Root_Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Root_Blocking_Object_Name, 8, 10)) )||')'
                   WHEN Root_Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                    Root_Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Root_Blocking_Object_Name, 7, 10)) )||')'
                   ELSE Root_Blocking_Object_Name
                 END)
             END Root_Blocking_Object,
             CASE WHEN COUNT(DISTINCT Root_Blocking_RowID) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Blocking_ROWID)||' >'
             ELSE
               MIN(CAST(Root_Blocking_RowID AS VARCHAR2(18)))
             END Root_Blocking_RowID,
             Root_Blocking_SQL_ID, Root_Blocking_SQL_Child_Number, Root_Blocking_Prev_SQL_ID, Root_Block_Prev_Child_Number,
             CASE WHEN COUNT(DISTINCT Root_WaitingForPKeyColumnName) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_WaitingForPKeyColumnName)||' >'
             ELSE
               MIN(Root_WaitingForPKeyColumnName)
             END Root_WaitingForPKeyColumnName,
             CASE WHEN COUNT(DISTINCT Root_WaitingForPKeyValue) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_WaitingForPKeyValue)||' >'
             ELSE
               MIN(Root_WaitingForPKeyValue)
             END Root_WaitingForPKeyValue,
             Root_Blocking_Status, Root_Blocking_Client_Info,
             Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_UserName, Root_Blocking_Machine, Root_Blocking_OSUser,
             Root_Blocking_Process, Root_Blocking_Program,
             NULL Blocking_App_Desc
      FROM   (
              SELECT CONNECT_BY_ROOT SnapshotTS               Root_SnapshotTS,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo,
                     CONNECT_BY_ROOT Blocking_Object_Schema   Root_Blocking_Object_Schema,
                     CONNECT_BY_ROOT Blocking_Object_Name     Root_Blocking_Object_Name,
                     CONNECT_BY_ROOT Blocking_RowID           Root_Blocking_RowID,
                     CONNECT_BY_ROOT Blocking_SQL_ID          Root_Blocking_SQL_ID,
                     CONNECT_BY_ROOT Blocking_SQL_Child_Number Root_Blocking_SQL_Child_Number,
                     CONNECT_BY_ROOT Blocking_Prev_SQL_ID     Root_Blocking_Prev_SQL_ID,
                     CONNECT_BY_ROOT Blocking_Prev_Child_Number Root_Block_Prev_Child_Number,
                     CONNECT_BY_ROOT WaitingForPKeyColumnName Root_WaitingForPKeyColumnName,
                     CONNECT_BY_ROOT WaitingForPKeyValue      Root_WaitingForPKeyValue,
                     CONNECT_BY_ROOT Blocking_Status          Root_Blocking_Status,
                     CONNECT_BY_ROOT Blocking_Client_Info     Root_Blocking_Client_Info,
                     CONNECT_BY_ROOT Blocking_Module          Root_Blocking_Module,
                     CONNECT_BY_ROOT Blocking_Action          Root_Blocking_Action,
                     CONNECT_BY_ROOT Blocking_UserName        Root_Blocking_UserName,
                     CONNECT_BY_ROOT Blocking_Machine         Root_Blocking_Machine,
                     CONNECT_BY_ROOT Blocking_OSUser          Root_Blocking_OSUser,
                     CONNECT_BY_ROOT Blocking_Process         Root_Blocking_Process,
                     CONNECT_BY_ROOT Blocking_Program         Root_Blocking_Program,
                     l.*,
                     Level cLevel
              FROM   TSSel l
              CONNECT BY NOCYCLE PRIOR SnapshotTS      = SnapshotTS
                     AND PRIOR sid             = blocking_sid
                     AND PRIOR instance_number = blocking_instance_number
                     AND PRIOR serialno        = blocking_serialNo
             ) l

      WHERE NOT EXISTS (SELECT 1 FROM TSSel i -- Nur die Knoten ohne Parent-Blocker darstellen
                        WHERE  i.SnapshotTS      = l.Root_SnapshotTS
                        AND    i.Instance_Number = l.Root_Blocking_Instance_Number
                        AND    i.SID             = l.Root_Blocking_SID
                        AND    i.SerialNo        = l.Root_Blocking_SerialNo
                       )
      GROUP BY Root_SnapshotTS, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_SerialNo,
               Root_Blocking_SQL_ID, Root_Blocking_SQL_Child_Number, Root_Blocking_Prev_SQL_ID, Root_Block_Prev_Child_Number,
               Root_Blocking_Status, Root_Blocking_Client_Info,
               Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_UserName, Root_Blocking_Machine, Root_Blocking_OSUser,
             Root_Blocking_Process, Root_Blocking_Program
      ORDER BY SUM(Seconds_In_Wait) DESC",
                            @time_selection_start, @time_selection_end]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc =  explain_application_info(l.root_blocking_module)
    }

    respond_to do |format|
      format.js {render :js => "$('#list_blocking_locks_history_area').html('#{j render_to_string :partial=>"list_blocking_locks_history_hierarchy" }');"}
    end
  end

  # Anzeige durch Blocking Locks gelockter Sessions in 2. und weiteren Hierarchie-Ebene
  def list_blocking_locks_history_hierarchy_detail
    @snapshotts         = params[:snapshotts]
    @blocking_instance  = params[:blocking_instance]
    @blocking_sid       = params[:blocking_sid]
    @blocking_serialno  = params[:blocking_serialno]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
                    WHERE  l.SnapshotTS = TO_DATE(?, '#{sql_datetime_second_mask}')
                   )
      SELECT o.Instance_Number, o.Sid, o.SerialNo, o.Seconds_In_Wait, o.SQL_ID, o.SQL_Child_Number,
             o.Prev_SQL_ID, o.Prev_Child_Number, o.Status, o.Client_Info, o.Module, o.Action, o.username, o.program,
             o.machine, o.osuser, o.process,
             CASE
               WHEN ObjectName LIKE 'SYS_LOB%%' THEN
                 ObjectName||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ObjectName, 8, 10)) )||')'
               WHEN ObjectName LIKE 'SYS_IL%%' THEN
                ObjectName||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ObjectName, 7, 10)) )||')'
               ELSE ObjectName
             END ObjectName,
             o.LockType, o.ID1, o.ID2, o.request, o.lockmode, o.Blocking_Object_Schema, o.Blocking_Object_Name,
             CAST(o.Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, o.WaitingForPKeyColumnName, o.WaitingForPKeyValue,
             NULL Waiting_App_Desc,
             cs.*,
             (SELECT COUNT(*) FROM TSel li
              WHERE li.Instance_Number=o.Instance_Number AND li.SID=o.SID AND li.SerialNo=o.SerialNo
             ) Samples
      FROM   TSel o
      JOIN   (-- Alle gelockten Sessions incl. mittelbare
              SELECT Root_Instance_Number, Root_SID, Root_SerialNo,
                     COUNT(DISTINCT CASE WHEN cLevel>1 THEN SID ELSE NULL END) Blocked_Sessions_Total,
                     COUNT(DISTINCT CASE WHEN cLevel=2 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
                     SUM(CASE WHEN CLevel>1 THEN Seconds_In_Wait ELSE 0 END ) Seconds_in_Wait_Blocked_Total
              FROM   (SELECT CONNECT_BY_ROOT Instance_Number Root_Instance_Number,
                             CONNECT_BY_ROOT SID             Root_SID,
                             CONNECT_BY_ROOT SerialNo        Root_SerialNo,
                             LEVEL cLevel,
                             l.*
                      FROM   tSel l
                      WHERE  l.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
                      CONNECT BY NOCYCLE PRIOR SnapshotTS      = SnapshotTS
                                     AND PRIOR sid             = blocking_sid
                                     AND PRIOR instance_number = blocking_instance_number
                                     AND PRIOR serialno        = blocking_serialNo
                      START WITH Blocking_Instance_Number=? AND Blocking_SID=? AND Blocking_SerialNo=?
                     )
              GROUP BY Root_Instance_Number, Root_SID, Root_SerialNo
             ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_SID = o.SID AND cs.Root_SerialNo = o.SerialNo
      WHERE  o.Blocking_Instance_Number = ?
      AND    o.Blocking_SID             = ?
      AND    o.Blocking_SerialNo        = ?
      AND    o.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
      ORDER BY o.Seconds_In_Wait+cs.Seconds_In_Wait_Blocked_Total DESC",
                            @snapshotts, @blocking_instance, @blocking_sid, @blocking_serialno, @blocking_instance, @blocking_sid, @blocking_serialno]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
    }

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_blocking_locks_history_hierarchy_detail" }');"}
    end
  end

  def list_blocking_locks_history_single_record
    where_from_blocking_locks_groupfilter(params[:groupfilter], nil)

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             SnapshotTS,
             Instance_Number,
             SID,         SerialNo,
             SQL_ID,      SQL_Child_Number,
             Prev_SQL_ID, Prev_Child_Number,
             Status,
             Client_Info, Module, Action,
             CASE
               WHEN ObjectName LIKE 'SYS_LOB%%' THEN
                 ObjectName||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ObjectName, 8, 10)) )||')'
               WHEN ObjectName LIKE 'SYS_IL%%' THEN
                ObjectName||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ObjectName, 7, 10)) )||')'
               ELSE ObjectName
             END ObjectName,
             Username, Machine, OSUser, Process, Program,
             LockType, Seconds_In_Wait, ID1, ID2, Request, LockMode,
             LOWER(Blocking_Object_Schema) Blocking_Object_Schema,
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END Blocking_Object_Name,
             CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID,
             WaitingForPKeyColumnName, WaitingForPKeyValue,
             Blocking_Instance_Number, Blocking_SID, Blocking_SerialNo,
             Blocking_SQL_ID, Blocking_SQL_Child_Number,
             Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number,
             Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action,
             Blocking_Username, Blocking_Machine, Blocking_OSUser, Blocking_Process, Blocking_Program,
             NULL Waiting_App_Desc,
             NULL Blocking_App_Desc
      FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
      WHERE  1 = 1 -- Dummy um nachfolgend mit AND fortzusetzen
      #{@where_string}
      ORDER BY SnapshotTS"].concat(@where_values)

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }


    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_blocking_locks_history_single_record" }');"}
    end
  end

  def list_blocking_locks_history_grouping
    where_from_blocking_locks_groupfilter(params[:groupfilter], params[:groupkey])

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             #{blocking_locks_groupfilter_values(@groupkey)[:sql]}   Group_Value,
             MIN(SnapshotTS)      Min_SnapshotTS,
             MAX(SnapshotTS)      Max_SnapshotTS,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
             COUNT(*)             Samples,
             CASE WHEN COUNT(DISTINCT Instance_Number) = 1 THEN TO_CHAR(MIN(Instance_Number)) ELSE '< '||COUNT(DISTINCT Instance_Number)||' >' END Instance_Number,
             CASE WHEN COUNT(DISTINCT SID)             = 1 THEN TO_CHAR(MIN(SID))             ELSE '< '||COUNT(DISTINCT SID)            ||' >' END SID,
             CASE WHEN COUNT(DISTINCT SerialNo)        = 1 THEN TO_CHAR(MIN(SerialNo))        ELSE '< '||COUNT(DISTINCT SerialNo)       ||' >' END SerialNo,
             CASE WHEN COUNT(DISTINCT SQL_ID)          = 1 THEN TO_CHAR(MIN(SQL_ID))          ELSE '< '||COUNT(DISTINCT SQL_ID)         ||' >' END SQL_ID,
             CASE WHEN COUNT(DISTINCT SQL_Child_Number)= 1 THEN TO_CHAR(MIN(SQL_Child_Number))ELSE '< '||COUNT(DISTINCT SQL_Child_Number)||' >' END SQL_Child_Number,
             CASE WHEN COUNT(DISTINCT Module)          = 1 THEN TO_CHAR(MIN(Module))          ELSE '< '||COUNT(DISTINCT Module)         ||' >' END Module,
             CASE WHEN COUNT(DISTINCT Objectname)      = 1 THEN TO_CHAR(MIN(ObjectName))      ELSE '< '||COUNT(DISTINCT ObjectName)     ||' >' END ObjectName,
             CASE WHEN COUNT(DISTINCT LockType)        = 1 THEN TO_CHAR(MIN(LockType))        ELSE '< '||COUNT(DISTINCT LockType)       ||' >' END LockType,
             CASE WHEN COUNT(DISTINCT Request)         = 1 THEN TO_CHAR(MIN(Request))         ELSE '< '||COUNT(DISTINCT Request)        ||' >' END Request,
             CASE WHEN COUNT(DISTINCT LockMode)        = 1 THEN TO_CHAR(MIN(LockMode))        ELSE '< '||COUNT(DISTINCT LockMode)       ||' >' END LockMode,
             CASE WHEN COUNT(DISTINCT Blocking_Object_Schema||'.'||Blocking_Object_Name) = 1 THEN TO_CHAR(MIN(LOWER(Blocking_Object_Schema)||'.'||Blocking_Object_Name))        ELSE '< '||COUNT(DISTINCT Blocking_Object_Schema||'.'||Blocking_Object_Name)||' >' END Blocking_Object,
             CASE WHEN COUNT(DISTINCT Blocking_RowID)  = 1 THEN CAST(MIN(Blocking_RowID) AS VARCHAR2(18)) ELSE '< '||COUNT(DISTINCT Blocking_RowID) ||' >' END Blocking_RowID,
             CASE WHEN COUNT(DISTINCT Blocking_Instance_Number) = 1 THEN TO_CHAR(MIN(Blocking_Instance_Number)) ELSE '< '||COUNT(DISTINCT Blocking_Instance_Number)||' >' END Blocking_Instance_Number,
             CASE WHEN COUNT(DISTINCT Blocking_SID)    = 1 THEN TO_CHAR(MIN(Blocking_SID))    ELSE '< '||COUNT(DISTINCT Blocking_SID)   ||' >' END Blocking_SID,
             CASE WHEN COUNT(DISTINCT Blocking_SerialNo)=1 THEN TO_CHAR(MIN(Blocking_SerialNo))ELSE '< '||COUNT(DISTINCT Blocking_SerialNo)||' >' END Blocking_SerialNo,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_ID) = 1 THEN TO_CHAR(MIN(Blocking_SQL_ID)) ELSE '< '||COUNT(DISTINCT Blocking_SQL_ID)||' >' END Blocking_SQL_ID,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_Child_Number)= 1 THEN TO_CHAR(MIN(Blocking_SQL_Child_Number))ELSE '< '||COUNT(DISTINCT Blocking_SQL_Child_Number)||' >' END Blocking_SQL_Child_Number
      FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
      WHERE  1 = 1
      #{@where_string}
      GROUP BY #{blocking_locks_groupfilter_values(@groupkey)[:sql]}
      ORDER BY 5 DESC"].concat(@where_values)


    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_blocking_locks_history_grouping" }');"}
    end
  end

  # Anzeige der Kakskade der Verursacher blockender Locks für eine konkrete Session
  def list_blocking_reason_cascade
    @snapshotts  = params[:snapshotts]
    @instance    = params[:instance]
    @sid         = params[:sid]
    @serialno    = params[:serialno]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{session[:dba_hist_blocking_locks_owner]}.DBA_Hist_Blocking_Locks l
                    WHERE  l.SnapshotTS = TO_DATE(?, '#{sql_datetime_second_mask}')
                    AND    l.Request != 0  -- nur Records beruecksichtigen, die wirklich auf Lock warten
                   )
      SELECT Level,
             ObjectName, LockType, Seconds_in_Wait, ID1, ID2, Request, LockMode,
             Blocking_Object_Schema||'.'||
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END  Blocking_Object, CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, Blocking_instance_Number, Blocking_SID, Blocking_SerialNo,
             Blocking_SQL_ID, Blocking_SQL_Child_Number, Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number, Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action, Blocking_UserName, Blocking_Machine, Blocking_OSUser, Blocking_Process, Blocking_Program,
             WaitingForPKeyColumnName, WaitingForPKeyValue,
             NULL Blocking_App_Desc
      FROM   TSel l
      CONNECT BY NOCYCLE PRIOR blocking_sid             = sid
                     AND PRIOR blocking_instance_number = instance_number
                     AND PRIOR blocking_serialno        = serialNo
      START WITH Instance_Number=? AND SID=? AND SerialNo=?",
                            @snapshotts, @instance, @sid,@serialno]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_blocking_reason_cascade" }');"}
    end
  end


  def show_object_increase
    @tablespaces = sql_select_all("SELECT '[Alle]' Name FROM DUAL UNION ALL SELECT Tablespace_Name Name FROM DBA_Tablespaces ORDER BY Name")
    @schemas     = sql_select_all("SELECT '[Alle]' Name FROM DUAL UNION ALL SELECT UserName Name FROM DBA_Users ORDER BY Name")

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"show_object_increase" }');"}
    end
  end


  def list_object_increase
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    list_object_increase_detail if params[:detail]
    list_object_increase_timeline if params[:timeline]
  end

  private
  # in welchem Schema liegt Tabelle OG_SEG_SPACE_IN_TBS
  def schema_of_OG_SEG_SPACE_IN_TBS
    schemas = sql_select_all "SELECT Owner FROM All_Tables WHERE Table_Name='OG_SEG_SPACE_IN_TBS'"
    raise "Tabelle OG_SEG_SPACE_IN_TBS findet sich in mehreren Schemata: erwartet wird genau ein Schema mit dieser Tabelle! #{schemas}" if schemas.count > 1
    raise "Tabelle OG_SEG_SPACE_IN_TBS in keinem Schema der DB gefunden" if schemas.count == 0
    schemas[0].owner
  end

  public

  def list_object_increase_detail
    @schema = schema_of_OG_SEG_SPACE_IN_TBS
    wherestr = ""
    whereval = []

    if params[:schema][:name] != '[Alle]'
      wherestr << " AND Owner=? "
      whereval << params[:schema][:name]
    end

    if params[:tablespace][:name] != '[Alle]'
      wherestr << " AND Last_TS=? "
      whereval << params[:tablespace][:name]
    end


    @incs = sql_select_all ["
        SELECT s.*, End_Mbytes-Start_MBytes Aenderung_Abs,
        CASE WHEN Start_MBytes != 0 THEN (End_MBytes/Start_MBytes-1)*100 END Aenderung_Pct
        FROM   (SELECT /*+ PARALLEL(s,2) */
                       Owner, Segment_Name, Segment_Type,
                       MAX(Tablespace_Name) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) Last_TS,
                       MIN(Gather_Date) Date_Start,
                       MAX(Gather_Date) Date_End,
                       MIN(MBytes) KEEP (DENSE_RANK FIRST ORDER BY Gather_Date) Start_Mbytes,
                       MAX(MBytes) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) End_Mbytes,
                       REGR_SLOPE(MBytes, Gather_Date-TO_DATE('1900', 'YYYY')) Anstieg
                FROM   #{@schema}.OG_SEG_SPACE_IN_TBS s
                WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
                AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
                GROUP BY Owner, Segment_Name, Segment_Type
               ) s
        WHERE  Start_MBytes != End_MBytes
        #{wherestr}
        ORDER BY End_Mbytes-Start_MBytes DESC",
                            @time_selection_start, @time_selection_end
                           ].concat(whereval)

    render_partial "list_object_increase_detail"
  end

  def list_object_increase_timeline
    @schema = schema_of_OG_SEG_SPACE_IN_TBS
    groupby = params[:gruppierung][:tag]

    wherestr = ""
    whereval = []

    if params[:schema][:name] != '[Alle]'
      wherestr << " AND Owner=? "
      whereval << params[:schema][:name]
    end

    if params[:tablespace][:name] != '[Alle]'
      wherestr << " AND Last_TS=? "
      whereval << params[:tablespace][:name]
    end


    sizes = sql_select_all ["
        SELECT /*+ PARALLEL(s,2) */
               Gather_Date,
               #{groupby} GroupBy,
               SUM(MBytes) MBytes
        FROM   #{@schema}.OG_SEG_SPACE_IN_TBS s
        WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
        AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
        #{wherestr}
        GROUP BY Gather_Date, #{groupby}
        ORDER BY Gather_Date, #{groupby}",
                            @time_selection_start, @time_selection_end
                           ].concat(whereval)


    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec.gather_date)},   :title=>"Zeitpunkt der Aufzeichnung der Größe"},
        ]

    @sizes = []
    columns = {}
    record = {:gather_date=>sizes[0].gather_date} if sizes.length > 0   # 1. Record mit Vergleichsdatum
    sizes.each do |s|
      if record[:gather_date] != s.gather_date  # Gruppenwechsel Datum
        @sizes << record
        record = {:gather_date=>s.gather_date}  # Neuer Record
      end
      record[:total] = 0 unless record[:total]
      record[:total] += s.mbytes
      record[s.groupby] = s.mbytes
      columns[s.groupby] = 1  if s.mbytes > 0  # Spalten unterdrücken ohne werte
    end
    @sizes << record if sizes.length > 0  # letzten Record sichern

    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec[:gather_date])},   :title=>"Zeitpunkt der Aufzeichnung der Größe", :plot_master_time=>true},
            {:caption=>"Total MB",        :data=>proc{|rec| formattedNumber(rec[:total])},        :title=>"Größe Total in MB", :align=>"right" }
        ]

    columns.each do |key, value|
      column_options << {:caption=>key, :data=>"formattedNumber(rec['#{key}'])", :title=>"Größe für '#{key}' in MB", :align=>"right" }
    end

    output = gen_slickgrid(@sizes, column_options, {
        :multiple_y_axes  => false,
        :show_y_axes      => true,
        :plot_area_id     => :list_object_increase_timeline_diagramm,
        :max_height       => 450,
        :caption          => "Zeitleiste nach #{groupby} aus #{@schema}.OG_SEG_SPACE_IN_TBS"
    })
    output << "</div><div id='list_object_increase_timeline_diagramm'></div>".html_safe


    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output }');"}
    end
  end

  def list_object_increase_object_timeline
    @schema = schema_of_OG_SEG_SPACE_IN_TBS
    save_session_time_selection
    owner = params[:owner]
    name  = params[:name]

    @sizes = sql_select_all ["
        SELECT /*+ PARALLEL(s,2) */
               Gather_Date,
               MBytes
        FROM   #{@schema}.OG_SEG_SPACE_IN_TBS s
        WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
        AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
        AND    Owner        = ?
        AND    Segment_Name = ?
        ORDER BY Gather_Date",
                             @time_selection_start, @time_selection_end, owner, name ]

    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec.gather_date)},   :title=>"Zeitpunkt der Aufzeichnung der Größe", :plot_master_time=>true},
            {:caption=>"Größe MB",        :data=>proc{|rec| formattedNumber(rec.mbytes)},        :title=>"Größe des Objektes in MB", :align=>"right" }
        ]

    output = gen_slickgrid(@sizes,
                           column_options,
                           {
                               :multiple_y_axes => false,
                               :show_y_axes     => true,
                               :plot_area_id    => :list_object_increase_object_timeline_diagramm,
                               :caption         => "Größenentwicklung #{owner}.#{name} aufgezeichnet in #{@schema}.OG_SEG_SPACE_IN_TBS",
                               :max_height      => 450
                           }
    )
    output << '<div id="list_object_increase_object_timeline_diagramm"></div>'.html_safe

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output }');"}
    end
  end


end
