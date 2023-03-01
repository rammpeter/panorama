 # encoding: utf-8

require 'json'
# Zusatzfunktionen, die auf speziellen Tabellen und Prozessen aufsetzen, die nicht prinzipiell in DB vorhanden sind
class AdditionController < ApplicationController
  include AdditionHelper
  include ExplainPlanHelper

  def list_db_cache_historic
    max_result_count = params[:maxResultCount]
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    save_session_time_selection                  # Werte puffern fuer spaetere Wiederverwendung

    if @show_partitions == '1'
      partition_expression = "Partition_Name"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (SELECT Instance_Number, Owner, Name, Partition_Name,
                     AVG(Blocks_Total) AvgBlocksTotal,
                     MIN(Blocks_Total) MinBlocksTotal,
                     Max(Blocks_Total) MaxBlocksTotal,
                     SUM(Blocks_Total) SumBlocksTotal,
                     AVG(Blocks_Dirty) AvgBlocksDirty,
                     MIN(Blocks_Dirty) MinBlocksDirty,
                     MAX(Blocks_Dirty) MaxBlocksDirty,
                     COUNT(*)         Samples,
                     AVG(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
              FROM   (SELECT Instance_Number, Owner, Name, #{partition_expression} Partition_Name,
                             SUM(Blocks_Total)            Blocks_Total,
                             SUM(Blocks_Dirty)            Blocks_Dirty,
                             MIN(Sum_Total_per_Snapshot)  Sum_Total_per_Snapshot /* Always the same per group condition */
                      FROM   (SELECT o.*,
                                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
                              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
                              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                              #{" AND Instance_Number=#{@instance}" if @instance}
                             )
                      -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                      GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
                     )
              GROUP BY Instance_Number, Owner, Name, Partition_Name
              ORDER BY SUM(Blocks_Total) DESC
             )
      WHERE RowNum <= ?",
                              @time_selection_start, @time_selection_end, max_result_count
                             ]

    render_partial
  end

  def list_db_cache_historic_detail
    @instance = prepare_param_instance
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @owner           = params[:owner]
    @name            = params[:name]
    @partitionname   = params[:partitionname]
    @partitionname   = nil if @partitionname == ''
    @show_partitions = params[:show_partitions]

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Snapshot_Timestamp,
             SUM(Blocks_Total) Blocks_Total,
             SUM(Blocks_Dirty) Blocks_Dirty,
             MIN(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
      FROM   (
              SELECT o.*,
                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
              AND    Instance_Number  = ?
             )
      WHERE  Owner            = ?
      AND    Name             = ?
      #{" AND Partition_Name = ?" if @partitionname}
      GROUP BY Snapshot_Timestamp
      ORDER BY Snapshot_Timestamp
      "].concat([@time_selection_start, @time_selection_end, @instance, @owner, @name].concat(@partitionname ? [@partitionname] : [])
                             )

    render_partial
  end


  def list_db_cache_historic_snap
    @instance           = prepare_param_instance
    @snapshot_timestamp = params[:snapshot_timestamp]
    @show_partitions    = params[:show_partitions]

    if @show_partitions == '1'
      partition_expression = "Partition_Name"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Owner, Name, #{partition_expression} Partition_Name,
             SUM(Blocks_Total) Blocks_Total,
             SUM(Blocks_Dirty) Blocks_Dirty,
             MIN(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
      FROM   (SELECT o.*,
                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
              WHERE  Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
              AND    Instance_Number   = ?
             )
      GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
      ORDER BY Blocks_Total DESC
      ", @snapshot_timestamp, @instance]

    render_partial
  end

  def list_db_cache_historic_timeline
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]

    if @show_partitions == '1'
      partition_expression = "c.Partition_Name"
    else
      partition_expression = "NULL"
    end

    singles = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             c.Instance_Number, c.Snapshot_Timestamp, c.Owner, c.Name, #{partition_expression} Partition_Name, SUM(c.Blocks_Total) Blocks_Total
      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Cache_Objects c
      JOIN   (
              SELECT Instance_Number, Owner, Name, Partition_Name, SumBlocksTotal
              FROM   (SELECT Instance_Number, Owner, Name, Partition_Name,
                             Max(Blocks_Total) MaxBlocksTotal,
                             SUM(Blocks_Total) SumBlocksTotal
                      FROM   (SELECT Instance_Number, Owner, Name, #{partition_expression} Partition_Name,
                                     SUM(Blocks_Total) Blocks_Total
                              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Cache_Objects c
                              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                              #{" AND Instance_Number=#{@instance}" if @instance}
                              -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                              GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
                             )
                      GROUP BY Instance_Number, Owner, Name, Partition_Name
                      ORDER BY Max(Blocks_Total) DESC
                     )
              WHERE RowNum <= 10
             ) s ON s.Instance_Number = c.Instance_Number AND s.Owner = c.Owner AND s.Name||s.Partition_Name = c.Name||#{partition_expression}
      WHERE  c.Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{" AND c.Instance_Number=#{@instance}" if @instance}
      GROUP BY c.Instance_Number, c.SnapShot_Timestamp, c.Owner, c.Name, #{partition_expression}
      ORDER BY c.Snapshot_Timestamp, MIN(s.SumBlocksTotal) DESC
      ",
                              @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end,
                             ]

    @snapshots = []           # Result-Array
    headers={}               # Spalten
    record = {}
    singles.each do |s|     # Iteration über einzelwerte
      record[:snapshot_timestamp] = s.snapshot_timestamp unless record[:snapshot_timestamp] # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record[:snapshot_timestamp] != s.snapshot_timestamp
        @snapshots << record
        record = {}
        record[:snapshot_timestamp] = s.snapshot_timestamp
      end
      colname = "#{"(#{s.instance_number}) " unless @instance}#{s.owner}.#{s.name} #{"(#{s.partition_name})" if s.partition_name}"
      record[colname] = s.blocks_total
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
        output << "[#{milliSec1970(s[:snapshot_timestamp])}, #{s[key]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    diagram_caption = "Top 10 Objekte im DB-Cache von #{@time_selection_start} bis #{@time_selection_end} #{"Instance=#{@instance}" if @instance}"

    unique_id = get_unique_area_id
    plot_area_id = "plot_area_#{unique_id}"
    output << "plot_diagram('#{unique_id}', '#{plot_area_id}', '#{diagram_caption}', data_array, {plot_diagram: {locale: '#{get_locale}'}, yaxis: { min: 0 } });"
    output << "});"

    html="
      <div id='#{plot_area_id}'></div>
      <script type='test/javascript'>
        #{ output}
      </script>
      ".html_safe

    respond_to do |format|
      format.html {render :html => html }
    end
  end # list_db_cache_historic_timeline

  def list_blocking_locks_history
    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung
    @min_wait_ms = prepare_param_int :min_wait_ms

    # Sprungverteiler nach diversen commit-Buttons
    list_blocking_locks_history_sum       if params[:commit_table]
    list_blocking_locks_history_hierarchy if params[:commit_hierarchy]

  end

  def list_blocking_locks_history_sum
    @timeslice = params[:timeslice]
    # Initiale Belegung des Groupfilters, wird dann immer weiter gegeben
    groupfilter = {}

    unless params[:show_non_blocking]     # non-Blocking filtern
      groupfilter = {"Hide_Non_Blocking" => '0' }
    end

    where_from_blocking_locks_groupfilter(groupfilter, nil)


    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             MIN(Snapshot_Timestamp)      Min_Snapshot_Timestamp,
             MAX(Snapshot_Timestamp)      Max_Snapshot_Timestamp,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
             COUNT(*)             Samples,
             #{distinct_expr_for_blocking_locks}
      FROM   (SELECT l.*,
                     (TO_CHAR(Snapshot_Timestamp,'J') * 24 + TO_CHAR(Snapshot_Timestamp, 'HH24')) * 60 + TO_CHAR(Snapshot_Timestamp, 'MI') Minutes
              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
              #{@where_string}
             )
      GROUP BY TRUNC(Minutes/ #{@timeslice})
      HAVING SUM(Seconds_In_Wait)*1000 > ?
      ORDER BY 1",
                            @time_selection_start, @time_selection_end].concat(@where_values).concat([@min_wait_ms])

    render_partial :list_blocking_locks_history_sum
  end

  # Anzeige Blocker/Blocking Kaskaden, Einstiegsschirm / 1. Seite mit Root-Blockern
  def list_blocking_locks_history_hierarchy
    @locks= sql_select_all ["\
     WITH /* Panorama-Tool Ramm */
           TSSel AS (SELECT /*+ NO_MERGE */ *
                      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                      WHERE  l.Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                      AND    l.Blocking_SID IS NOT NULL  -- keine langdauernden Locks beruecksichtigen
                    )
      SELECT Root_Snapshot_Timestamp, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_Serial_No,
             COUNT(DISTINCT SID) Blocked_Sessions_Total,
             COUNT(DISTINCT CASE WHEN cLevel=1 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
             SUM(Seconds_In_Wait)                                      Seconds_in_wait_Total,
             CASE WHEN COUNT(DISTINCT Root_Blocking_Object_Owner||Root_Blocking_Object_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Blocking_Object_Owner||Root_Blocking_Object_Name)||' >'
             ELSE
               MIN(Root_Blocking_Object_Owner||'.'||
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
             CASE WHEN COUNT(DISTINCT Root_Wait_For_PK_Column_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Wait_For_PK_Column_Name)||' >'
             ELSE
               MIN(Root_Wait_For_PK_Column_Name)
             END Root_Wait_For_PK_Column_Name,
             CASE WHEN COUNT(DISTINCT Root_Waiting_For_PK_Value) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Waiting_For_PK_Value)||' >'
             ELSE
               MIN(Root_Waiting_For_PK_Value)
             END Root_Waiting_For_PK_Value,
             Root_Blocking_Event,
             Root_Blocking_Status, Root_Blocking_Client_Info,
             Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_User_Name, Root_Blocking_Machine, Root_Blocking_OS_User,
             Root_Blocking_Process, Root_Blocking_Program,
             NULL Blocking_App_Desc
      FROM   (
              SELECT CONNECT_BY_ROOT Snapshot_Timestamp       Root_Snapshot_Timestamp,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_Serial_No        Root_Blocking_Serial_No,
                     CONNECT_BY_ROOT Blocking_Object_Owner    Root_Blocking_Object_Owner,
                     CONNECT_BY_ROOT Blocking_Object_Name     Root_Blocking_Object_Name,
                     CONNECT_BY_ROOT Blocking_RowID           Root_Blocking_RowID,
                     CONNECT_BY_ROOT Blocking_SQL_ID          Root_Blocking_SQL_ID,
                     CONNECT_BY_ROOT Blocking_SQL_Child_Number Root_Blocking_SQL_Child_Number,
                     CONNECT_BY_ROOT Blocking_Prev_SQL_ID     Root_Blocking_Prev_SQL_ID,
                     CONNECT_BY_ROOT Blocking_Prev_Child_Number Root_Block_Prev_Child_Number,
                     CONNECT_BY_ROOT Blocking_Event           Root_Blocking_Event,
                     CONNECT_BY_ROOT Waiting_For_PK_Column_Name Root_Wait_For_PK_Column_Name,
                     CONNECT_BY_ROOT Waiting_For_PK_Value     Root_Waiting_For_PK_Value,
                     CONNECT_BY_ROOT Blocking_Status          Root_Blocking_Status,
                     CONNECT_BY_ROOT Blocking_Client_Info     Root_Blocking_Client_Info,
                     CONNECT_BY_ROOT Blocking_Module          Root_Blocking_Module,
                     CONNECT_BY_ROOT Blocking_Action          Root_Blocking_Action,
                     CONNECT_BY_ROOT Blocking_User_Name       Root_Blocking_User_Name,
                     CONNECT_BY_ROOT Blocking_Machine         Root_Blocking_Machine,
                     CONNECT_BY_ROOT Blocking_OS_User         Root_Blocking_OS_User,
                     CONNECT_BY_ROOT Blocking_Process         Root_Blocking_Process,
                     CONNECT_BY_ROOT Blocking_Program         Root_Blocking_Program,
                     l.*,
                     Level cLevel
              FROM   TSSel l
              CONNECT BY NOCYCLE PRIOR Snapshot_Timestamp   = Snapshot_Timestamp
                     AND PRIOR sid                          = blocking_sid
                     AND PRIOR instance_number              = blocking_instance_number
                     AND PRIOR serial_no                     = blocking_serial_no
             ) l

      WHERE NOT EXISTS (SELECT 1 FROM TSSel i -- Nur die Knoten ohne Parent-Blocker darstellen
                        WHERE  i.Snapshot_Timestamp = l.Snapshot_Timestamp
                        AND    i.Instance_Number    = l.Root_Blocking_Instance_Number
                        AND    i.SID                = l.Root_Blocking_SID
                        AND    i.Serial_No           = l.Root_Blocking_Serial_No
                       )
      GROUP BY Root_Snapshot_Timestamp, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_Serial_No,
               Root_Blocking_SQL_ID, Root_Blocking_SQL_Child_Number, Root_Blocking_Prev_SQL_ID, Root_Block_Prev_Child_Number,
               Root_Blocking_Event, Root_Blocking_Status, Root_Blocking_Client_Info,
               Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_User_Name, Root_Blocking_Machine, Root_Blocking_OS_User,
             Root_Blocking_Process, Root_Blocking_Program
      HAVING SUM(Seconds_In_Wait)*1000 > ?
      ORDER BY SUM(Seconds_In_Wait) DESC",
                            @time_selection_start, @time_selection_end, @min_wait_ms]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc =  explain_application_info(l.root_blocking_module)
    }

    render_partial :list_blocking_locks_history_hierarchy
  end

  # Anzeige durch Blocking Locks gelockter Sessions in 2. und weiteren Hierarchie-Ebene
  def list_blocking_locks_history_hierarchy_detail
    @snapshot_timestamp = params[:snapshot_timestamp]
    @blocking_instance  = params[:blocking_instance]
    @blocking_sid       = params[:blocking_sid]
    @blocking_serial_no  = params[:blocking_serial_no]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                    WHERE  l.Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
                    AND    l.Blocking_SID IS NOT NULL  -- keine langdauernden Locks beruecksichtigen
                   )
      SELECT o.Instance_Number, o.Sid, o.Serial_No, o.Seconds_In_Wait, o.SQL_ID, o.SQL_Child_Number,
             o.Prev_SQL_ID, o.Prev_Child_Number, o.Event, o.Status, o.Client_Info, o.Module, o.Action, o.user_name, o.program,
             o.machine, o.os_user, o.process,
             CASE
               WHEN Object_Name LIKE 'SYS_LOB%%' THEN
                 Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 8, 10)) )||')'
               WHEN Object_Name LIKE 'SYS_IL%%' THEN
                Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 7, 10)) )||')'
               ELSE Object_Name
             END Object_Name,
             o.Lock_Type, o.ID1, o.ID2, o.request, o.lock_mode, o.Blocking_Object_Owner, o.Blocking_Object_Name,
             CAST(o.Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, o.Waiting_For_PK_Column_Name, o.Waiting_For_PK_Value,
             NULL Waiting_App_Desc,
             cs.*,
             (SELECT COUNT(*) FROM TSel li
              WHERE li.Instance_Number=o.Instance_Number AND li.SID=o.SID AND li.Serial_No=o.Serial_No
             ) Samples
      FROM   TSel o
      JOIN   (-- Alle gelockten Sessions incl. mittelbare
              SELECT Root_Instance_Number, Root_SID, Root_Serial_No,
                     COUNT(DISTINCT CASE WHEN cLevel>1 THEN SID ELSE NULL END) Blocked_Sessions_Total,
                     COUNT(DISTINCT CASE WHEN cLevel=2 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
                     SUM(CASE WHEN CLevel>1 THEN Seconds_In_Wait ELSE 0 END ) Seconds_in_Wait_Blocked_Total
              FROM   (SELECT CONNECT_BY_ROOT Instance_Number Root_Instance_Number,
                             CONNECT_BY_ROOT SID             Root_SID,
                             CONNECT_BY_ROOT Serial_No        Root_Serial_No,
                             LEVEL cLevel,
                             l.*
                      FROM   tSel l
                      CONNECT BY NOCYCLE PRIOR Snapshot_Timestamp = Snapshot_Timestamp
                                     AND PRIOR sid                = blocking_sid
                                     AND PRIOR instance_number    = blocking_instance_number
                                     AND PRIOR serial_no           = blocking_serial_no
                      START WITH Blocking_Instance_Number=? AND Blocking_SID=? AND Blocking_Serial_No=?
                     )
              GROUP BY Root_Instance_Number, Root_SID, Root_Serial_No
             ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_SID = o.SID AND cs.Root_Serial_No = o.Serial_No
      WHERE  o.Blocking_Instance_Number = ?
      AND    o.Blocking_SID             = ?
      AND    o.Blocking_Serial_No        = ?
      ORDER BY o.Seconds_In_Wait+cs.Seconds_In_Wait_Blocked_Total DESC",
                            @snapshot_timestamp, @blocking_instance, @blocking_sid, @blocking_serial_no, @blocking_instance, @blocking_sid, @blocking_serial_no]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
    }

    render_partial
  end

  def list_blocking_locks_history_single_record
    where_from_blocking_locks_groupfilter(params[:groupfilter], nil)

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             Snapshot_Timestamp,
             Instance_Number,
             SID,         Serial_No,
             SQL_ID,      SQL_Child_Number,
             Prev_SQL_ID, Prev_Child_Number,
             Event, Status,
             Client_Info, Module, Action,
             CASE
               WHEN Object_Name LIKE 'SYS_LOB%%' THEN
                 Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 8, 10)) )||')'
               WHEN Object_Name LIKE 'SYS_IL%%' THEN
                Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 7, 10)) )||')'
               ELSE Object_Name
             END Object_Name,
             User_Name, Machine, OS_User, Process, Program,
             Lock_Type, Seconds_In_Wait, ID1, ID2, Request, Lock_Mode,
             LOWER(Blocking_Object_Owner) Blocking_Object_Owner,
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END Blocking_Object_Name,
             CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID,
             Waiting_For_PK_Column_Name, Waiting_For_PK_Value,
             Blocking_Instance_Number, Blocking_SID, Blocking_Serial_No,
             Blocking_SQL_ID, Blocking_SQL_Child_Number,
             Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number,
             Blocking_Event, Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action,
             Blocking_User_Name, Blocking_Machine, Blocking_OS_User, Blocking_Process, Blocking_Program,
             NULL Waiting_App_Desc,
             NULL Blocking_App_Desc
      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
      WHERE  1 = 1 -- Dummy um nachfolgend mit AND fortzusetzen
      #{@where_string}
      ORDER BY Snapshot_Timestamp"].concat(@where_values)

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }


    render_partial
  end

  def list_blocking_locks_history_grouping
    where_from_blocking_locks_groupfilter(params[:groupfilter], params[:groupkey])

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             #{blocking_locks_groupfilter_values(@groupkey)[:sql]}   Group_Value,
             MIN(Snapshot_Timestamp)      Min_Snapshot_Timestamp,
             MAX(Snapshot_Timestamp)      Max_Snapshot_Timestamp,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
                 COUNT(*)             Samples,
             #{distinct_expr_for_blocking_locks}
      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
      WHERE  1 = 1
      #{@where_string}
      GROUP BY #{blocking_locks_groupfilter_values(@groupkey)[:sql]}
      ORDER BY 5 DESC"].concat(@where_values)

    render_partial
  end

  # Anzeige der Kakskade der Verursacher blockender Locks für eine konkrete Session
  def list_blocking_reason_cascade
    @snapshot_timestamp = params[:snapshot_timestamp]
    @instance           = params[:instance]
    @sid                = params[:sid]
    @serial_no           = params[:serial_no]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                    WHERE  l.Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
                    AND    l.Blocking_SID IS NOT NULL  -- keine langdauernden Locks beruecksichtigen
                   )
      SELECT Level,
             Instance_Number, SID, Serial_No, SQL_ID, Event, Module, Action, Object_Name, User_Name, Lock_Type, Seconds_in_Wait, ID1, ID2, Request, Lock_Mode,
             Blocking_Object_Owner||'.'||
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END  Blocking_Object, CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, Blocking_instance_Number, Blocking_SID, Blocking_Serial_No,
             Blocking_SQL_ID, Blocking_SQL_Child_Number, Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number, Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action, Blocking_User_Name, Blocking_Machine, Blocking_OS_User, Blocking_Process, Blocking_Program,
             Waiting_For_PK_Column_Name, Waiting_For_PK_Value,
             NULL Blocking_App_Desc
      FROM   TSel l
      CONNECT BY NOCYCLE PRIOR blocking_sid             = sid
                     AND PRIOR blocking_instance_number = instance_number
                     AND PRIOR blocking_serial_no        = serial_no
      START WITH Instance_Number=? AND SID=? AND Serial_No=?",
                            @snapshot_timestamp, @instance, @sid,@serial_no]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    render_partial
  end


  def show_object_increase
    @tablespaces = sql_select_all("SELECT Tablespace_Name Name FROM DBA_Tablespaces ORDER BY Name")
    @schemas     = sql_select_all("SELECT UserName Name FROM DBA_Users ORDER BY Name")

    @tablespaces.insert(0,  {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))
    @schemas.insert(0,      {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))

    render_partial
  end


  def list_object_increase
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    @wherestr = ""
    @whereval = []

    @schema_name = nil
    if params[:schema][:name] != all_dropdown_selector_name
      @schema_name = params[:schema][:name]
      @wherestr << " AND Owner=? "
      @whereval << @schema_name
    end

    @tablespace_name = nil                                                      # initialization
    if params[:tablespace][:name] != all_dropdown_selector_name
      @tablespace_name = params[:tablespace][:name]
      @wherestr << " AND Tablespace_Name=? "
      @whereval << @tablespace_name
    end


    list_object_increase_detail if params[:detail]
    list_object_increase_timeline if params[:timeline]
  end

  def list_object_increase_detail
    @row_count_changes = params[:row_count_changes] == '1'

    @incs = sql_select_all ["
      SELECT s.*,
             End_Mbytes - Start_MBytes       Aenderung_Abs,
             (End_MBytes/Start_MBytes-1)*100 Aenderung_Pct
      FROM   (
              SELECT Owner, Segment_Name, Segment_Type,
                     CASE WHEN Segment_Type LIKE 'LOB%' THEN (SELECT Table_Name||'.'||Column_Name FROM DBA_Lobs l WHERE l.Owner = s.Owner AND l.Segment_Name = s.Segment_Name) END Name_Addition,
                     MAX(Greatest_TS) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) Last_TS,
                     MAX(Tablespaces) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) Tablespaces,
                     MIN(Bytes/(1024*1024))KEEP (DENSE_RANK FIRST ORDER BY Gather_Date)  Start_Mbytes,
                     MAX(Bytes/(1024*1024))KEEP (DENSE_RANK LAST  ORDER BY Gather_Date)  End_Mbytes,
                     MIN(Num_Rows) KEEP (DENSE_RANK FIRST ORDER BY Gather_Date)          Start_Num_Rows,
                     MAX(Num_Rows) KEEP (DENSE_RANK LAST  ORDER BY Gather_Date)          End_Num_Rows,
                     MIN(Gather_Date) Min_Gather_Date,
                     MAX(Gather_Date) Max_Gather_Date
              FROM   (SELECT Owner, Segment_Name, Segment_Type, Gather_Date,
                             SUM(Bytes) Bytes, MIN(Num_Rows) Num_Rows,                  -- num_rows per record are over all tablespaces
                             MAX(Tablespace_Name) KEEP (DENSE_RANK LAST ORDER BY Bytes) Greatest_TS,
                             COUNT(DISTINCT Tablespace_Name)                            Tablespaces
                      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes
                      WHERE  Gather_Date BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                      #{@wherestr}
                      GROUP BY Owner, Segment_Name, Segment_Type, Gather_Date -- group over all tablespaces
                     ) s
              GROUP BY Owner, Segment_Name, Segment_Type
             ) s
      WHERE  NVL(Start_MBytes, 0) != NVL(End_MBytes, 0)
      #{"OR     NVL(Start_Num_Rows, 0) != NVL(End_Num_Rows, 0)" if @row_count_changes}
      ORDER BY NVL(End_Mbytes, 0) - NVL(Start_MBytes, 0) DESC
    ", @time_selection_start, @time_selection_end].concat(@whereval)

    render_partial "list_object_increase_detail"
  end

  def list_object_increase_timeline
    @update_area = get_unique_area_id
    groupby = params[:gruppierung][:tag]

    sql_groupby = groupby
    sql_groupby = compact_object_type_sql_case(groupby) if groupby == 'Segment_Type'


    sizes = sql_select_all ["
        SELECT /*+ PARALLEL(s,2) */
               Gather_Date,
               #{sql_groupby} GroupBy,
               SUM(Bytes)/(1024*1024) MBytes
        FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
        WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
        AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
        #{@wherestr}
        GROUP BY Gather_Date, #{sql_groupby}
        ORDER BY Gather_Date, #{sql_groupby}",
                            @time_selection_start, @time_selection_end
                           ].concat(@whereval)

    @sizes = []
    columns = {}
    record = {:gather_date=>sizes[0].gather_date} if sizes.length > 0   # 1. Record mit Vergleichsdatum
    sizes.each do |s|
      if record[:gather_date] != s.gather_date  # Gruppenwechsel Datum
        @sizes << record
        record = {:gather_date=>s.gather_date}  # Neuer Record
      end
      # noinspection RubyScope
      record[:total] = 0 unless record[:total]
      record[:total] += s.mbytes
      record[s.groupby] = s.mbytes
      columns[s.groupby] = 1  if s.mbytes > 0  # Spalten unterdrücken ohne werte
    end
    @sizes << record if sizes.length > 0  # letzten Record sichern

    # iterate through result rows
    prev_record = nil
    @sizes.each do |s|
      unless prev_record.nil?
        s[:total_increase] = s[:total] - prev_record[:total]
        columns.each do |key, _|
          s["#{key}_increase"] = s[key] - prev_record[key] rescue nil           # not every category must have values or prevrecords / nil possible
        end
      end

      prev_record = s
    end

    link_mbytes = proc do |rec, key, value|
      ajax_link(fn(value, 2), {
          action:               :list_object_increase_objects_per_time,
          gather_date:          localeDateTime(rec[:gather_date]),
          groupby =>            key,                                            # filter criteria for column
          Tablespace_Name:      @tablespace_name,                               # optional filter criteria from previous dialog
          Owner:                @schema_name,                                   # optional filter criteria from previous dialog
          time_selection_start: @time_selection_start,
          time_selection_end:   @time_selection_end,
          update_area:          @update_area
      }, :title=>"Show objects of this column for gather date and selection criterias")
    end

    link_total_mbytes = proc do |rec|
      ajax_link(fn(rec[:total], 2), {
          action:               :list_object_increase_objects_per_time,
          gather_date:          localeDateTime(rec[:gather_date]),
          Tablespace_Name:      @tablespace_name,                               # optional filter criteria from previous dialog
          Owner:                @schema_name,                                   # optional filter criteria from previous dialog
          time_selection_start: @time_selection_start,
          time_selection_end:   @time_selection_end,
          update_area:          @update_area
      }, :title=>"Show all objects for gather date and selection criterias")
    end


    column_options =
        [
            {:caption=>"Gather date",     :data=>proc{|rec| localeDateTime(rec[:gather_date])},   :title=>"Timestamp of object size snapshot", :plot_master_time=>true},
            {:caption=>"Total MB",        :data=>link_total_mbytes,                               :title=>"Total size for filter criterias in MBytes", :align=>"right" },
            {:caption=>"Total incr. MB",  data: proc{|rec| fn(rec[:total_increase])},             :title=>"Total increase since last snapshot for filter criterias in MBytes", :align=>"right" },
        ]

    columns.each do |key, value|
      column_options << {:caption=>key, :data=>proc{|rec| link_mbytes.call(rec, key, rec[key])}, :title=>"Size for #{key} in MB", :align=>"right" }
      column_options << {caption: "#{key} incr.", data: proc{|rec| fn(rec["#{key}_increase"])},  :title=>"Increase since last snapshot for #{key} in MB", :align=>"right" }
    end

    output = gen_slickgrid(@sizes, column_options, {
        :multiple_y_axes  => false,
        :show_y_axes      => true,
        :plot_area_id     => @update_area,
        :max_height       => 450,
        :caption          => "Size evolution over time grouped by #{groupby} from #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes#{", Tablespace='#{@tablespace_name}'" if @tablespace_name}#{", Schema='#{@schema_name}'" if @schema_name}"
    })
    output << "</div><div id='#{@update_area}'></div>".html_safe


    respond_to do |format|
      format.html {render :html => output }
    end
  end

  def time_for_object_increase
    @owner = params[:owner]
    @name  = params[:name]
    render_partial
  end

  def list_object_increase_objects_per_time
    save_session_time_selection
    @gather_date     = prepare_param(:gather_date)

    @segment_type    = prepare_param(:Segment_Type)
    @owner           = prepare_param(:Owner)
    @tablespace_name = prepare_param(:Tablespace_Name)

    where_string = ''
    where_values = []

    if @segment_type
      where_string << " AND #{compact_object_type_sql_case('Segment_Type')} = ?"
      where_values << @segment_type
    end

    if @owner
      where_string << " AND Owner = ?"
      where_values << @owner
    end

    if @tablespace_name
      where_string << " AND Tablespace_Name = ?"
      where_values << @tablespace_name
    end

    @objects = sql_select_all ["\
      SELECT *
      FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
      WHERE  Gather_Date = TO_DATE(?, '#{sql_datetime_second_mask}')
      #{where_string}
      ORDER BY Bytes DESC
      ", @gather_date ].concat(where_values)

    render_partial
  end

  def list_object_increase_object_timeline
    save_session_time_selection
    owner = params[:owner]
    name  = params[:name]

    @sizes = sql_select_all ["
      SELECT Gather_Date, Greatest_TS, Tablespaces, MBytes, Num_Rows,
             MBytes - LAG(MBytes, 1, MBytes) OVER (ORDER BY Gather_Date) Increase_MB
      FROM   (
              SELECT Gather_Date,
                     SUM(Bytes)/(1024*1024) MBytes,
                     MIN(Num_Rows) Num_Rows,                  -- Num_rows per record are over all tablespaces in sum
                      MAX(Tablespace_Name) KEEP (DENSE_RANK LAST ORDER BY Bytes) Greatest_TS,
                      COUNT(DISTINCT Tablespace_Name)                            Tablespaces
              FROM   #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
              WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
              AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
              AND    Owner        = ?
              AND    Segment_Name = ?
              GROUP BY Gather_Date
             )
      ORDER BY Gather_Date",
                             @time_selection_start, @time_selection_end, owner, name ]

    show_ts = proc do |rec|
      if rec.tablespaces == 1
        rec.greatest_ts
      else
        "<&nbsp;#{rec.tablespaces}&nbsp;different&nbsp;>"
      end
    end

    column_options =
        [
            {:caption=>"Date",            :data=>proc{|rec| localeDateTime(rec.gather_date)},         :title=>"Timestamp of gathering object size",       :plot_master_time=>true},
            {:caption=>"Tablespace",      :data=>show_ts,                                             :title=>"Tablespace or number of different tablespaces"},
            {:caption=>"Size MB",         :data=>proc{|rec| formattedNumber(rec.mbytes, 2)},          :title=>"Size of object in MB at gather time",      :align=>"right" },
            {:caption=>"Increase (MB)",   :data=>proc{|rec| formattedNumber(rec.increase_mb, 2)},     :title=>"Size increase in MB since last snapshot",  :align=>"right" },
            {:caption=>"Num. rows",       :data=>proc{|rec| fn(rec.num_rows)},                        :title=>"Number of rows of object at snapshot time (from last preceding analyze run)",              :align=>:right},
        ]

    output = gen_slickgrid(@sizes,
                           column_options,
                           {
                               :multiple_y_axes => false,
                               :show_y_axes     => true,
                               :plot_area_id    => :list_object_increase_object_timeline_diagramm,
                               :caption         => "Size evolution of object #{owner}.#{name} recorded in #{PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema]}.Panorama_Object_Sizes",
                               :max_height      => 450
                           }
    )
    output << '<div id="list_object_increase_object_timeline_diagramm"></div>'.html_safe

    respond_to do |format|
      format.html {render :html => output }
    end
  end

  # call action given by parameters
  def exec_recall_params
    begin
      parameter_info = JSON.parse(params[:parameter_info])
      raise "wrong ruby class '#{parameter_info.class}'! Expression must be of ruby class 'Hash' (comparable to JSON)." if parameter_info.class != Hash
    rescue Exception => e
      show_popup_message("#{e.class} while evaluating expression:\n#{e.message}")
      return
    end

    parameter_info.symbolize_keys!
    parameter_info[:update_area]     = params[:update_area]
    parameter_info[:browser_tab_id]  = @browser_tab_id

    redirect_to url_for(:controller => parameter_info[:controller],:action => parameter_info[:action], :params => parameter_info, :method=>:post)

  end

  def exec_worksheet_sql
    @caption = nil

    @sql_statement = prepare_sql_statement(params[:sql_statement])              # remove trailing semicolon if not PL/SQL
    show_popup_message('No SQL statement found') if @sql_statement.nil? || @sql_statement == ''
    # remove comments from SQL
    stripped_sql_statement = remove_comments_from_sql(@sql_statement)

    @expected_binds = find_binds_in_sql(@sql_statement)
    @binds = binds_from_params(@expected_binds, params)
    if all_binds_defined?(@expected_binds, @binds)
      remember_binds_for_next_usage(@binds)
      # choose execution type and execute
      if stripped_sql_statement.upcase =~ /^SELECT/ || stripped_sql_statement.upcase =~ /^WITH/
        @res = []
        PanoramaConnection::SqlSelectIterator.new(stmt: PackLicense.filter_sql_for_pack_license(@sql_statement), binds: ar_binds_from_binds(@binds), query_name: 'exec_worksheet_sql').each {|r| @res << r}
        remember_last_executed_sql_id                                           # remember the SQL-ID for SQL details view
        render_partial :list_dragnet_sql_result, controller: :dragnet
      else
        PanoramaConnection.sql_execute_native(sql: PackLicense.filter_sql_for_pack_license(@sql_statement), binds: ar_binds_from_binds(@binds), query_name: 'exec_worksheet_sql')
        remember_last_executed_sql_id                                           # remember the SQL-ID for SQL details view
        render html: "<div class='page_caption'>Statement executed at #{localeDateTime(Time.now)}</div>
        #{render_code_mirror(@sql_statement)}\n".html_safe
      end
    else
      @update_area = prepare_param :update_area
      @requested_action = action_name                                           # repeat this action after setting binds
      @modus_name       = 'Execute'
      render_partial :set_expected_binds
    end
  end

  def explain_worksheet_sql
    if params[:sql_statement].nil? || params[:sql_statement] == ''
      show_popup_message('Nothing to explain: No statement typed')
      return
    end
    @sql_statement = prepare_sql_statement(params[:sql_statement])       # remove trailing semicolon
    @expected_binds = find_binds_in_sql(@sql_statement)
    @binds = binds_from_params(@expected_binds, params)

    if all_binds_defined?(@expected_binds, @binds)
      remember_binds_for_next_usage(@binds)

      statement_id = get_unique_area_id

      PanoramaConnection.sql_execute_native(sql: "EXPLAIN PLAN SET Statement_ID='#{statement_id}' FOR #{@sql_statement}", binds: ar_binds_from_binds(@binds), query_name: 'explain_worksheet_sql')
      @plans = sql_select_all ["\
          SELECT p.*,
                 NVL(t.Num_Rows, i.Num_Rows) Num_Rows,
                 NVL(t.Last_Analyzed, i.Last_Analyzed) Last_Analyzed,
                 o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_TS,
                 (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner=p.Object_Owner AND s.Segment_Name=p.Object_Name) MBytes
          FROM   Plan_Table p
          LEFT OUTER JOIN DBA_Tables  t ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name
          LEFT OUTER JOIN DBA_Indexes i ON i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name
          -- Object_Type ensures that only one record is gotten from DBA_Objects even if object is partitioned
          LEFT OUTER JOIN DBA_Objects o ON o.Owner = p.Object_Owner AND o.Object_Name = p.Object_Name AND o.Object_Type = p.Object_Type
          WHERE  Statement_ID = ?
          ORDER BY ID
          ", statement_id]

      raise "Column 'DEPTH' missing in your Plan_Table (old structure)!\nPlease drop your local plan table to ensure usage of builtin public Plan_Table." if @plans.length > 0 && @plans[0]['depth'].nil?

      calculate_execution_order_in_plan(@plans)                                   # Calc. execution order by parent relationship

      render_partial
      PanoramaConnection.sql_execute ["DELETE FROM Plan_Table WHERE STatement_ID = ?", statement_id]

    else
      @update_area = prepare_param :update_area
      @requested_action = action_name                                           # repeat this action after setting binds
      @modus_name       = 'Explain'
      render_partial :set_expected_binds
    end
  end

  private

  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_blocking_locks_groupfilter (groupfilter, groupkey)
    @groupfilter = groupfilter
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
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

  def distinct_expr(column_name, nvl_replace, column_alias=nil, direct_access=nil)
    local_replace = nvl_replace
    local_replace = "'#{nvl_replace}'" if nvl_replace.instance_of? String
    column_alias  = column_name if column_alias.nil?
    direct_access = "TO_CHAR(MIN(#{column_name}))" if direct_access.nil?
    "#{direct_access} #{column_alias}_Min,
COUNT(DISTINCT NVL(#{column_name}, #{local_replace})) #{column_alias}_Cnt"
  end

  def distinct_expr_for_blocking_locks
    "#{distinct_expr('Instance_Number',         0)},
     #{distinct_expr('SID',                     0)},
     #{distinct_expr('serial_No',                0)},
     #{distinct_expr('SQL_ID',                  '-1')},
     #{distinct_expr('SQL_Child_Number',        -1)},
     #{distinct_expr('Event',                   '-1')},
     #{distinct_expr('Module',                  '-1')},
     #{distinct_expr('Object_Name',             '-1')},
     #{distinct_expr('Lock_Type',               '-1')},
     #{distinct_expr('Request',                 '-1')},
     #{distinct_expr('Lock_Mode',               '-1')},
     #{distinct_expr("Blocking_Object_Owner||'.'||Blocking_Object_Name",   '', 'Blocking_Object')},
     #{distinct_expr('Blocking_RowID',          '', 'Blocking_RowID', 'CAST(MIN(Blocking_RowID) AS VARCHAR2(18))')},
     #{distinct_expr('Blocking_Instance_Number', 0)},
     #{distinct_expr('Blocking_SID',             0)},
     #{distinct_expr('Blocking_Serial_No',        0)},
     #{distinct_expr('Blocking_SQL_ID',          '-1')},
     #{distinct_expr('Blocking_SQL_Child_Number',-1)},
     #{distinct_expr('Blocking_Event',           '-1')},
     #{distinct_expr('Blocking_Status',          '-1')}
    "
  end

  # remove trailing semicomon if needed
  def prepare_sql_statement(sql)
    sql.rstrip!
    lines = sql.split("\n")
    if lines.count > 0 && lines[lines.length-1].strip.upcase != 'END;'
      sql.gsub!(/;$/, "")
    end
    sql
  end

  def remove_comments_from_sql(sql)
    stripped_sql_statement = sql.split("\n").select{|s| s.strip[0,2] != '--'}.join("\n") # remove full line comments
    stripped_sql_statement.gsub!(/\/\*.*?\*\//m, '')                            # remove /* comments */ also for multiple lines
    stripped_sql_statement
  end

  def remove_string_literals(sql)
    without_escaped = sql.gsub(/''/m, '')
    without_escaped.gsub(/'.*'/m, '')
  end

  # @param [String] sql The statement
  # @return Array with Hash { alias, value, type}
  def find_binds_in_sql(sql)
    remaining = remove_string_literals(remove_comments_from_sql(sql))
    result = []
    stored_binds = read_from_client_info_store(:bind_aliases) || {}
    while remaining[':'] do
      remaining = remaining[remaining.index(':')+1..]
      end_pos = remaining.length
      [' ', ')', ']', ';', "\r", "\n"].each do |end_char|
        end_pos = remaining.index(end_char) if remaining.index(end_char) && remaining.index(end_char) < end_pos
      end
      bind_alias = remaining[0, end_pos]
      result << {
        alias: bind_alias,
        value: stored_binds[bind_alias] ? stored_binds[bind_alias][:value] : nil,
        type:  stored_binds[bind_alias] ? stored_binds[bind_alias][:type]  : 'Content dependent'
      }
    end
    result
  end

  # Check if all expected aliases are in defined array
  # @param [Array] expected Array of hashes with { alias, value, type}
  # @param [Array] defined
  # @return [TrueClass, FalseClass]
  def all_binds_defined?(expected, defined)
    expected.each_index do |i|
      return false if i > defined.length-1 || expected[i][:alias] != defined[i][:alias]
    end
    true
  end

  # Store used bind values
  # @param [Array] binds
  def remember_binds_for_next_usage(binds)
    stored_binds = read_from_client_info_store(:bind_aliases)
    stored_binds = {} if stored_binds.nil?
    binds.each do |bind|
      stored_binds[bind[:alias]] = bind
    end
    write_to_client_info_store(:bind_aliases, stored_binds)
  end

  # read the bind values from params into Hash
  # @param [Array] expected_binds Array of hashes with { alias, value, type}
  # @param param Request parameter
  # @return [Array] { alias, value, type}
  def binds_from_params(expected_binds, params)
    result = []
    expected_binds.each do |expb|
      if params["alias_#{expb[:alias]}"]
        result << {
          alias: expb[:alias],
          value: params["alias_#{expb[:alias]}"],
          type:  params["type_#{expb[:alias]}"]
        }
      end
    end
    result
  end

  # translate binds to AR structure
  # @param [Array] binds
  def ar_binds_from_binds(binds)
    ar_binds = []
    binds.each do |bind|
      typed_value = case bind[:type]
                    when 'Content dependent' then Float(bind[:value]) rescue bind[:value]
                    when 'String'     then bind[:value]
                    when 'Integer'    then Integer(bind[:value])
                    when 'Float'      then Float(bind[:value])
                    when 'Date/Time'  then DateTime.parse(bind[:value])
                    else raise "Unsupported type '#{bind[:type]}'"
                    end
      ar_binds << ActiveRecord::Relation::QueryAttribute.new(":#{bind[:alias]}", typed_value, worksheet_bind_types[bind[:type]][:type_class].new)
    end
    ar_binds
  end

  # persist the SQL ID of the last executed statement in this session
  def remember_last_executed_sql_id
    sql_id = sql_select_one "SELECT Prev_SQL_ID FROM v$Session WHERE SID=SYS_CONTEXT('USERENV', 'SID')"
    write_to_client_info_store(:last_used_worksheet_sql_id, sql_id)
  end
end

