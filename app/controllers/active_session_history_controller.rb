# encoding: utf-8

# require 'jruby/profiler'
require 'json'

class ActiveSessionHistoryController < ApplicationController
  # include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include ActiveSessionHistoryHelper

  private

  # SQL-Fragment zur Mehrfachverwendung in diversen SQL
  def include_session_statistic_historic_default_select_list
    retval = " MIN(Sample_Time)             First_Occurrence,
               MAX(Sample_Time)             Last_Occurrence,
               -- So komisch wegen Konvertierung Tiemstamp nach Date für Subtraktion
               (TO_DATE(TO_CHAR(MAX(Sample_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}') -
               TO_DATE(TO_CHAR(MIN(Sample_Time), '#{sql_datetime_second_mask}'), '#{sql_datetime_second_mask}'))*(24*60*60) Sample_Dauer_Secs"

    session_statistics_key_rules.each do |_key, value|
      retval << ",
        COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) #{value[:sql_alias]}_Cnt,
        MIN(#{value[:sql]}) #{value[:sql_alias]}"
    end
    retval
  end

  public

  # Anzeige DBA_Hist_Active_Sess_History
  def list_session_statistic_historic
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @instance = prepare_param_instance
    params[:groupfilter] = {}
    params[:groupfilter][:DBID]                  = prepare_param_dbid
    params[:groupfilter][:Instance]              = @instance if @instance
    params[:groupfilter][:Idle_Wait1]            = 'PX Deq Credit: send blkd' unless params[:idle_waits] == '1'
    params[:groupfilter][:time_selection_start]  = @time_selection_start
    params[:groupfilter][:time_selection_end]    = @time_selection_end

    params[:groupfilter][:Additional_Filter]     = params[:filter].strip  if params[:filter] && params[:filter] != ''

    list_session_statistic_historic_grouping      # Weiterleiten Request an Standard-Verarbeitung für weiteres DrillDown
  end # list_session_statistic_historic

  # Anzeige Diagramm mit Top10
  def list_session_statistic_historic_timeline
    group_seconds = params[:group_seconds].to_i

    where_from_groupfilter(params[:groupfilter], params[:groupby])
    @dbid = params[:groupfilter][:DBID]       # identische DBID verwenden wie im groupfilter bereits gesetzt

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    singles= sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             -- Beginn eines zu betrachtenden Zeitabschnittes
             TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400 Start_Sample,
             NVL(TO_CHAR(#{session_statistics_key_rule(@groupby)[:sql]}), 'NULL') Criteria,
             SUM(s.Sample_Cycle / CASE WHEN s.Sample_Cycle > #{group_seconds} THEN #{group_seconds}*s.Sample_Cycle ELSE #{group_seconds} END) Diagram_Value
      FROM   (#{ash_select(awr_filter: @dba_hist_where_string, sga_filter: @sga_ash_where_string)})s
      LEFT OUTER JOIN DBA_Users             u   ON u.User_ID     = s.User_ID
      LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID   = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID  = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE 1=1 #{@global_where_string}
      GROUP BY TRUNC(Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY 1
     "].concat(@dba_hist_where_values).concat(@sga_ash_where_values).concat([@dbid]).concat(@global_where_values))


    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ''
    @groupfilter.each do |key, value|
      @filter << "#{groupfilter_value(key)[:name]}=\"#{value}\", " unless groupfilter_value(key)[:hide_content]
    end

    diagram_caption = "#{t(:active_session_history_list_session_statistic_historic_timeline_header,
                                                   :default=> 'Number of waiting sessions condensed by %{group_seconds} seconds for top-10 grouped by: <b>%{groupby}</b>, Filter: %{filter}',
                                                   :group_seconds=>group_seconds, :groupby=>@groupby, :filter=>@filter
    )}"

    next_update_area_id = get_unique_area_id

    plotselected_handler = "(xstart_ms,xend_ms)=>{
    let json_data            = #{ {:groupfilter => @groupfilter}.to_json.html_safe };
    json_data['groupby']     = '#{@groupby}';
    json_data['xstart_ms']   = xstart_ms;
    json_data['xend_ms']     = xend_ms;
    json_data['update_area'] = '#{next_update_area_id}';
    delete json_data.groupfilter.Min_Snap_ID;                                   // should be calculated again based on xstart_ms
    delete json_data.groupfilter.Max_Snap_ID;                                   // should be calculated again based on xend_ms

    ajax_html('#{next_update_area_id}', 'active_session_history', 'list_session_statistic_historic_grouping_with_ms_times', json_data);
    }"

    plot_top_x_diagramm(:data_array         => singles,
                        :time_key_name      => 'start_sample',
                        :curve_key_name     => 'criteria',
                        :value_key_name     => 'diagram_value',
                        :top_x              => 10,
                        :caption            => diagram_caption,
                        :null_points_cycle  => group_seconds,
                        :update_area        => params[:update_area],
                        plotselected_handler: plotselected_handler,
                        next_update_area_id: next_update_area_id
    )
  end # list_session_statistic_historic_timeline

  private

  # Generieren des SQL-Snippets für Alternativ-Anzeige
  def single_record_distinct_sql(column, alias_name=nil)
    unless alias_name
      alias_name = column
      alias_name = column[column.index('.')+1, column.length] if column.index('.')     # Tabellen-Alias entfernen
    end

    retval = ''
    retval << "CASE WHEN COUNT(DISTINCT #{column}) > 1 THEN NULL ELSE MIN(#{column}) END #{alias_name}, "
    retval << "COUNT(DISTINCT #{column}) #{alias_name}_Cnt"
  end


  public

  # Anlisten der Einzel-Records eines Gruppierungskriteriums
  def list_session_statistic_historic_single_record

    # additional SQL needed for Joining
    additional_join = ''                                                        # Default if not needed
    if params[:groupfilter][:Blocking_Event]
      left_outer_join = false                                                   # Default if special columns don't require left outer join

      if params[:groupfilter][:Blocking_Event] == 'IDLE'
        left_outer_join = true
        params[:groupfilter][:Blocking_Event] = ''
      end

      if params[:groupfilter][:Blocking_Event]['GLOBAL']
        left_outer_join = true
        params[:groupfilter].delete :Blocking_Event
        params[:groupfilter][:Blocking_Session_Status] = 'GLOBAL'
      end

      additional_join = "\
      #{left_outer_join ? 'LEFT OUTER' : ''} JOIN ash blocking
      ON blocking.Instance_Number = s.Blocking_Inst_ID AND blocking.Session_ID = s.Blocking_Session
         AND blocking.Session_Serial_No = s.Blocking_Session_Serial_No AND blocking.Rounded_Sample_Time = s.Rounded_Sample_Time
    "
    end

    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt


    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    if !defined?(@time_groupby) || @time_groupby.nil? || @time_groupby == ''
      record_count = params[:record_count].to_i
      @time_groupby = :single        # Default
      @time_groupby = :hour if record_count > 1000
    end

    group_by_value = case @time_groupby.to_sym
      when :single    then "s.Sample_ID, s.Instance_Number, s.Session_ID"         # Direkte Anzeige der Snapshots
      when :second    then "TO_NUMBER(TO_CHAR(s.Sample_Time, 'DDD')) * 86400 + TO_NUMBER(TO_CHAR(s.Sample_Time, 'SSSSS'))"
      when :second10  then "TO_NUMBER(TO_CHAR(s.Sample_Time, 'DDD')) * 8640 + TRUNC(TO_NUMBER(TO_CHAR(s.Sample_Time, 'SSSSS'))/10)"
      when :minute    then "TRUNC(s.Sample_Time, 'MI')"
      when :hour      then "TRUNC(s.Sample_Time, 'HH24')"
      when :day       then "TRUNC(s.Sample_Time)"
      when :week      then "TRUNC(s.Sample_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    record_modifier = proc{|rec|
      rec['sql_operation'] = translate_opcode(rec.sql_opcode)
    }

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE MATERIALIZE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures),
      #{ash_select(awr_filter:                  @dba_hist_where_string,
                   sga_filter:                  @sga_ash_where_string,
                   select_rounded_sample_time:  true,
                   with_cte_alias:              'ash'
                  )}
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             MIN(s.Sample_Time)         Start_Sample_Time,
             MAX(s.Sample_Time)         End_Sample_Time,
             MIN(s.Rounded_Sample_Time) Start_Rounded_Sample_Time,
             MAX(s.Rounded_Sample_Time) End_Rounded_Sample_Time,
             COUNT(*)                   Sample_Count,
             AVG(s.Sample_Cycle)        Sample_Cycle,
             SUM(s.Sample_Cycle)        Wait_Time_Seconds_Sample,
             #{ single_record_distinct_sql('s.Instance_Number') },
             #{"#{ single_record_distinct_sql('s.Con_ID') }," if get_current_database[:cdb]}
             #{ single_record_distinct_sql('s.Sample_ID') },
             #{ single_record_distinct_sql('s.Session_id') },
             #{ single_record_distinct_sql('s.Session_Type') },
             #{ single_record_distinct_sql('s.Session_Serial_No') },
             #{ single_record_distinct_sql('s.User_ID') },
             #{ single_record_distinct_sql('s.SQL_Child_Number') },
             #{ single_record_distinct_sql('s.SQL_Plan_Hash_Value') },
             #{ single_record_distinct_sql('s.SQL_Opcode') },
             #{ single_record_distinct_sql('s.Session_State') },
             #{ single_record_distinct_sql('s.Blocking_Session') },
             #{ single_record_distinct_sql('s.Blocking_session_Status') },
             #{ single_record_distinct_sql('s.Blocking_session_Serial_No') },
             #{ single_record_distinct_sql('s.Blocking_Hangchain_Info') },
             #{ single_record_distinct_sql('s.Event') },
             #{ single_record_distinct_sql('s.Event_ID') },
             #{ single_record_distinct_sql('s.Sequence') },
             #{ single_record_distinct_sql('s.P1Text') },
             #{ single_record_distinct_sql('s.P1') },
             #{ single_record_distinct_sql('s.P2Text') },
             #{ single_record_distinct_sql('s.P2') },
             #{ single_record_distinct_sql('s.P3Text') },
             #{ single_record_distinct_sql('s.P3') },
             #{ single_record_distinct_sql('s.Wait_Class') },
             #{ single_record_distinct_sql('s.Program') },
             #{ single_record_distinct_sql('s.Module') },
             #{ single_record_distinct_sql('s.Action') },
             #{ single_record_distinct_sql('s.Client_ID') },
             #{ single_record_distinct_sql('s.Current_Obj_No') },
             #{ single_record_distinct_sql('s.Current_File_No') },
             #{ single_record_distinct_sql('s.Current_Block_No') },
             #{ single_record_distinct_sql('s.Tx_ID') },
             #{ single_record_distinct_sql('s.QC_Session_ID') },
             #{ single_record_distinct_sql('s.QC_Instance_ID') },
             #{ single_record_distinct_sql('s.SQL_ID') },
             SUM(s.Wait_Time)       Wait_Time,
             SUM(s.Time_waited)     Time_Waited,
             MAX(s.Time_Waited)     Max_Time_Waited,
             #{" #{ single_record_distinct_sql('s.Is_SQLID_Current') },
                 #{ single_record_distinct_sql('s.Top_Level_SQL_ID') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Line_ID') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Operation') },
                 #{ single_record_distinct_sql('s.SQL_Plan_Options') },
                 #{ single_record_distinct_sql('s.SQL_Exec_ID') },
                 #{ single_record_distinct_sql('s.SQL_Exec_Start') },
                 #{ single_record_distinct_sql('s.Blocking_Inst_ID') },
                 #{ single_record_distinct_sql('s.Current_Row_No') },
                 #{ single_record_distinct_sql('s.Remote_Instance_No') },
                 #{ single_record_distinct_sql('s.Machine') },
                 #{ single_record_distinct_sql('s.Port') },
                 #{ single_record_distinct_sql('s.Modus') },
                 AVG(s.PGA_Allocated)           PGA_Allocated,
                 AVG(s.Temp_Space_Allocated)    Temp_Space_Allocated,
                 SUM(s.TM_Delta_Time_Secs)      TM_Delta_Time_Secs,
                 SUM(s.TM_Delta_CPU_Time_Secs)  TM_Delta_CPU_Time_Secs,
                 SUM(s.TM_Delta_DB_Time_Secs)   TM_Delta_DB_Time_Secs,
                 SUM(s.Delta_Time_Secs)         Delta_Time_Secs,
             " if get_db_version >= '11.2'}
             #{ single_record_distinct_sql('u.UserName') },
             '' SQL_Operation,
             #{ single_record_distinct_sql('o.Owner') },
             #{ single_record_distinct_sql('o.Object_Name') },
             #{ single_record_distinct_sql('o.SubObject_Name') },
             #{ single_record_distinct_sql('o.Data_Object_ID') },
             #{ single_record_distinct_sql('f.File_Name') },
             #{ single_record_distinct_sql('f.Tablespace_Name') },
             #{ single_record_distinct_sql('peo.Owner',           'PEO_Owner') },
             #{ single_record_distinct_sql('peo.Object_Name',     'PEO_Object_Name') },
             #{ single_record_distinct_sql('peo.Procedure_Name',  'PEO_Procedure_Name') },
             #{ single_record_distinct_sql('peo.Object_Type',     'PEO_Object_Type') },
             #{ single_record_distinct_sql('po.Owner',            'PO_Owner') },
             #{ single_record_distinct_sql('po.Object_Name',      'PO_Object_Name') },
             #{ single_record_distinct_sql('po.Procedure_Name',   'PO_Procedure_Name') },
             #{ single_record_distinct_sql('po.Object_Type',      'PO_Object_Type') },
             #{ single_record_distinct_sql('sv.Service_Name') },
             #{" #{ single_record_distinct_sql('s.QC_Session_Serial_No', 'QC_Session_Serial_No') },
                 SUM(s.TM_Delta_CPU_Time_Secs * s.Sample_Cycle / s.TM_Delta_Time_Secs) TM_CPU_Time_Secs_Sample_Cycle,  /* CPU-Time innerhalb des Sample-Cycle */
                 SUM(s.TM_Delta_DB_Time_Secs  * s.Sample_Cycle / s.TM_Delta_Time_Secs) TM_DB_Time_Secs_Sample_Cycle,
                 SUM(s.Delta_Read_IO_Requests       * s.Sample_Cycle / s.Delta_Time_Secs)  Read_IO_Requests_Sample_Cycle,
                 SUM(s.Delta_Write_IO_Requests      * s.Sample_Cycle / s.Delta_Time_Secs)  Write_IO_Requests_Sample_Cycle,
                 SUM(s.Delta_Read_IO_kBytes         * s.Sample_Cycle / s.Delta_Time_Secs)  Read_IO_kBytes_Sample_Cycle,
                 SUM(s.Delta_Write_IO_kBytes        * s.Sample_Cycle / s.Delta_Time_Secs)  Write_IO_kBytes_Sample_Cycle,
                 SUM(s.Delta_Interconnect_IO_kBytes * s.Sample_Cycle / s.Delta_Time_Secs)  Interconn_kBytes_Sample_Cycle,
             " if get_db_version >= '11.2'}
             MIN(RowNum) Row_Num
      FROM   ash s #{additional_join}
      LEFT OUTER JOIN DBA_Users u     ON u.User_ID = s.User_ID
      -- erst p2 abfragen, da bei Request=3 in row_wait_obj# das als vorletztes gelockte Object stehen kann
      LEFT OUTER JOIN DBA_Objects o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN procs peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv ON sv.DBID = ? AND sv.Service_Name_Hash = s.Service_Hash
      LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
     "
     ].concat(@dba_hist_where_values).concat(@sga_ash_where_values).concat([@dbid]).concat(@global_where_values), record_modifier)

    render_partial :list_session_statistic_historic_single_record
  end # list_session_statistic_historic_single_record


  # Generische Funktion zum Anlisten der verdichteten Einzel-Records eines Gruppierungskriteriums nach GroupBy
  def list_session_statistic_historic_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby])
    @dbid = params[:groupfilter][:DBID]        # identische DBID verwenden wie im groupfilter bereits gesetzt

    record_modifier = proc{|rec|
      # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
      # da die Tabellen nicht auf allen DB zur Verfügung stehen
      if @groupby=='Module' || @groupby=='Action'
        info = explain_application_info(rec.group_value)
        rec.info      = info[:short_info]
        rec.info_hint = info[:long_info]
      end
    }

    # Mysteriös: LEFT OUTER JOIN per s.Current_Obj# funktioniert nicht gegen ALL_Objects, wenn s.PLSQL_Entry_Object_ID != NULL
    @sessions= PanoramaConnection.sql_select_iterator(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             #{session_statistics_key_rule(@groupby)[:sql]}           Group_Value,
             #{if session_statistics_key_rule(@groupby)[:info_sql]
                 session_statistics_key_rule(@groupby)[:info_sql]
               else "''"
               end
              } Info,
             '' Info_Hint,
             MIN(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID,
             AVG(Time_Waited)/1000  Time_Waited_Avg_ms,
             MIN(Time_Waited)/1000  Time_Waited_Min_ms,
             MAX(Time_Waited)/1000  Time_Waited_Max_ms,
             SUM(s.Sample_Cycle)          Time_Waited_Secs,  -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
             MAX(s.Sample_Cycle)          Max_Sample_Cycle,  -- Max. Abstand der Samples als Korrekturgroesse fuer Berechnung LOAD
             #{'
                SUM(TM_Delta_CPU_Time_Secs)           TM_CPU_Time_Secs,  /* CPU-Time innerhalb des Sample-Cycle */
                SUM(TM_Delta_DB_Time_Secs)            TM_DB_Time_Secs,
                SUM(Delta_Read_IO_Requests)           Delta_Read_IO_Requests,
                SUM(Delta_Write_IO_Requests)          Delta_Write_IO_Requests,
                SUM(Delta_Read_IO_kBytes)             Delta_Read_IO_kBytes,
                SUM(Delta_Write_IO_kBytes)            Delta_Write_IO_kBytes,
                SUM(Delta_Interconnect_IO_kBytes)     Delta_Interconnect_IO_kBytes,
                MAX(PGA_Allocated)/(1024*1024)        Max_PGA_MB,
                AVG(PGA_Allocated)/(1024*1024)        Avg_PGA_MB,
                MAX(Temp_Space_Allocated)/(1024*1024) Max_Temp_MB,
                AVG(Temp_Space_Allocated)/(1024*1024) Avg_Temp_MB,
             ' if get_db_version >= '11.2'}
             COUNT(1)                     Count_Samples,
             #{include_session_statistic_historic_default_select_list}
      FROM   (#{ash_select(awr_filter: @dba_hist_where_string, sga_filter: @sga_ash_where_string, dbid: @dbid)})s
      LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END
      LEFT OUTER JOIN DBA_Users             u   ON u.User_ID   = s.User_ID  -- LEFT OUTER JOIN verursacht Fehler
      LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID
      LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID
      LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash
      LEFT OUTER JOIN DBA_Data_Files        f   ON f.File_ID = s.Current_File_No
      WHERE  1=1
      #{@global_where_string}
      GROUP BY s.DBID, #{session_statistics_key_rule(@groupby)[:sql]}
      ORDER BY SUM(s.Sample_Cycle) DESC
     "
     ].concat(@dba_hist_where_values).concat(@sga_ash_where_values).concat(@global_where_values),
                              record_modifier
    )

    #profile_data = JRuby::Profiler.profile do
      render_partial :list_session_statistic_historic_grouping
    #end

    #profile_printer = JRuby::Profiler::FlatProfilePrinter.new(profile_data)
    #profile_printer.printProfile(STDOUT)
  end

  # called from javascript with timestamps in ms since 1970
  def list_session_statistic_historic_grouping_with_ms_times
    xstart_ms = prepare_param_int :xstart_ms
    xend_ms   = prepare_param_int :xend_ms

    params[:groupfilter][:time_selection_start] = localeDateTime(Time.at(xstart_ms/1000).utc)
    params[:groupfilter][:time_selection_end]   = localeDateTime(Time.at(xend_ms/1000).utc)
    list_session_statistic_historic_grouping                                    # call with times as strings
  end

  # Auswahl von/bis
  # Vorbelegungen von diversen Filtern durch Übergabe im Param-Hash
  def show_prepared_active_session_history
    set_cached_time_selection_start(params[:time_selection_start]) if params[:time_selection_start] && params[:time_selection_start] != ''
    set_cached_time_selection_end(  params[:time_selection_end])   if params[:time_selection_end]   && params[:time_selection_end]   != ''

    @groupfilter = {:DBID       => prepare_param_dbid }

    @groupfilter[:Instance]                     =  params[:instance]                            if params[:instance]
    @groupfilter['SQL-ID'.to_sym]               =  params[:sql_id]                              if params[:sql_id]
    @groupfilter[:SQL_Child_Number]             =  params[:child_number]                        if params[:child_number]
    @groupfilter[:SQL_ID_or_Top_Level_SQL_ID]   =  params[:SQL_ID_or_Top_Level_SQL_ID]          if params[:SQL_ID_or_Top_Level_SQL_ID]
    @groupfilter['Session/Sn.'.to_sym]          =  "#{params[:sid]}, #{params[:serial_no]}"      if params[:sid] &&  params[:serial_no]
    @groupfilter[:Action]                       =  params[:module_action]                       if params[:module_action]
    @groupfilter['DB Object']                   =  params[:db_object]                           if params[:db_object]

    @groupby = 'Hugo' # Default
    @groupby = 'SQL-ID'       if params[:sql_id] || params[:SQL_ID_or_Top_Level_SQL_ID]
    @groupby = 'Session/Sn.'  if params[:sid] &&  params[:serial_no]
    @groupby = 'Action'       if params[:module_action]
    @groupby = 'DB Object'    if params[:db_object]

    render_partial
  end

  # Anzeige nach Eingabe von/bis in show_prepared_active_session_history
  def list_prepared_active_session_history
    save_session_time_selection
    params[:groupfilter][:time_selection_start] = @time_selection_start
    params[:groupfilter][:time_selection_end]   = @time_selection_end

    list_session_statistic_historic_grouping  # Weiterleiten
  end

  def refresh_time_selection
    params.require [:repeat_controller, :repeat_action]
    if params[:time_selection_start]
      params[:groupfilter][:time_selection_start] = params[:time_selection_start]
      params[:groupfilter].delete(:Min_Snap_ID)                                 # remove corresponding Snap_ID-Filter if time-selection may have changed
    end

    if params[:time_selection_end]
      params[:groupfilter][:time_selection_end]   = params[:time_selection_end]
      params[:groupfilter].delete(:Max_Snap_ID)                                 # remove corresponding Snap_ID-Filter if time-selection may have changed
    end

    params[:groupfilter].each do |key, value|
      params[:groupfilter].delete(key) if params[key] && params[key]=='' && key!='time_selection_start' && key!='time_selection_end' # Element aus groupfilter loeschen, dass namentlich im param-Hash genannt ist
      params[:groupfilter][key] = params[key] if params[key] && params[key]!=''
    end

    # send(params[:repeat_action])              # Ersetzt redirect_to, da dies in Kombination winstone + FireFox nicht sauber funktioniert (Get-Request wird über Post verarbeitet)

    redirect_to url_for(controller: params[:repeat_controller], action: params[:repeat_action], params: params.permit!, method: :post)
  end

  def fork_blocking_locks_historic_call
    case params[:commit]
    when 'Blocking locks session dependency tree' then list_blocking_locks_historic
    when 'Blocking locks event dependency' then list_blocking_locks_historic_event_dependency
    else raise "fork_blocking_locks_historic_call: No action configured for button '#{params[:commit]}'"
    end
  end

  def list_blocking_locks_historic
    @dbid = prepare_param_dbid
    save_session_time_selection
    @min_snap_id, @max_snap_id = get_min_max_snap_ids(@time_selection_start, @time_selection_end, @dbid, raise_if_not_found: true)

    @locks = sql_select_iterator [
      "WITH /* Panorama-Tool Ramm */
       #{ash_select(awr_filter:     "DBID = ? AND Snap_ID BETWEEN ? AND ?",
                    global_filter:  "     Sample_Time BETWEEN TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')",
                    select_rounded_sample_time: true,
                    with_cte_alias: 'Ash'
                   )},
       TSSel AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM Ash WHERE Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */),
       -- Komplette Menge an Samples erweitert um die Attribute des Root-Blockers
       root_sel as (SELECT  /*+ NO_MERGE MATERIALIZE */
                           CONNECT_BY_ROOT Rounded_Sample_Time      Root_Rounded_Sample_Time,
                           CONNECT_BY_ROOT Blocking_Session         Root_Blocking_Session,
                           CONNECT_BY_ROOT Blocking_Session_Serial_No Root_Blocking_Session_SerialNo,
                           CONNECT_BY_ROOT Blocking_Session_Status  Root_Blocking_Session_Status,
                           #{'CONNECT_BY_ROOT Blocking_Inst_ID  Root_Blocking_Inst_ID,' if get_db_version >= '11.2'}
                           CONNECT_BY_ROOT (CASE WHEN l.P2Text = 'object #' THEN /* Wait kennt Object */ l.P2 ELSE l.Current_Obj_No END) Root_Real_Current_Object_No,
                           CONNECT_BY_ROOT Instance_Number          Root_Instance_Number,
                           CONNECT_BY_ROOT SQL_ID                   Root_SQL_ID,
                           CONNECT_BY_ROOT User_ID                  Root_User_ID,
                           CONNECT_BY_ROOT Event                    Root_Event,
                           CONNECT_BY_ROOT Snap_ID                  Root_Snap_ID,
                           CONNECT_BY_ROOT Module                   Root_Module,
                           CONNECT_BY_ROOT Action                   Root_Action,
                           CONNECT_BY_ROOT Program                  Root_Program,
                           l.*,
                           Level cLevel,
                           Connect_By_IsCycle Is_Cycle
                    FROM   TSSel l
                    CONNECT BY NOCYCLE PRIOR Rounded_Sample_Time = Rounded_Sample_Time
                           AND PRIOR Session_ID           = Blocking_Session
                           AND PRIOR Session_Serial_No    = Blocking_Session_Serial_No
                            #{'AND PRIOR Instance_number   = Blocking_Inst_ID' if get_db_version >= '11.2'}
                   ),
       -- Samples verdichtet nach Root-Blocker für Statistische Aussagen
       root_sel_compr AS (SELECT /*+ NO_MERGE MATERIALIZE */
                                 Root_Blocking_Session, Root_Blocking_Session_SerialNo, Root_Blocking_Session_Status #{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'},
                                 MIN(l.Root_Rounded_Sample_Time)-(MAX(Sample_Cycle)/86400)  Min_Sample_Time,            /* wegen Nachfolgendem BETWEEN-Vergleich der gerundeten Zeiten auf vorherigen Sample_Cycle abgrenzen */
                                 MAX(l.Root_Rounded_Sample_Time)+(MIN(Sample_Cycle)/86400)  Max_Sample_Time,            /* wegen Nachfolgendem BETWEEN-Vergleich der gerundeten Zeiten auf nächsten Sample_Cycle abgrenzen */
                                 MIN(l.Snap_ID)                                             Min_Snap_ID,
                                 MAX(l.Snap_ID)                                             Max_Snap_ID,
                                 #{if get_db_version >= '11.2'
                                      'CASE WHEN COUNT(DISTINCT l.Current_File_No)  = 1 THEN MIN(l.Current_File_No)  ELSE NULL END Current_File_No,
                                       CASE WHEN COUNT(DISTINCT l.Current_Block_No) = 1 THEN MIN(l.Current_Block_No) ELSE NULL END Current_Block_No,
                                       CASE WHEN COUNT(DISTINCT l.Current_Row_No)   = 1 THEN MIN(l.Current_Row_No)   ELSE NULL END Current_Row_No,
                                      '
                                    end
                                  }
                                 CASE WHEN COUNT(DISTINCT l.Instance_Number||'.'||l.Session_ID||'.'||l.Session_Serial_No) > 1 THEN  '< '||COUNT(DISTINCT l.Instance_Number||'.'||l.Session_ID||'.'||l.Session_Serial_No)||' >' ELSE MIN(TO_CHAR(l.Session_ID)) END Blocked_Sessions_Total,
                                 CASE WHEN COUNT(DISTINCT l.Instance_Number) > 1 THEN  '< '||COUNT(DISTINCT l.Instance_Number)||' >' ELSE MIN(TO_CHAR(l.Instance_Number)) END Waiting_Instance,
                                 CASE WHEN COUNT(DISTINCT CASE WHEN cLevel=1 THEN l.Instance_Number||'.'||l.Session_ID||'.'||l.Session_Serial_No ELSE NULL END) > 1 THEN
                                   '< '||COUNT(DISTINCT CASE WHEN cLevel=1 THEN l.Instance_Number||'.'||l.Session_ID||'.'||l.Session_Serial_No ELSE NULL END)||' >'
                                 ELSE
                                   MIN(CASE WHEN cLevel=1 THEN TO_CHAR(l.Session_ID) ELSE NULL END)
                                 END Blocked_Sessions_Direct,
                                 SUM(l.Sample_Cycle)              Seconds_in_Wait_Sample,  /* Wartezeit auf Basis der anzahl ASH-Samples */
                                 CASE WHEN COUNT(DISTINCT o.Object_Type)    = 1 THEN MAX(o.Object_Type)                                                      END Root_Blocking_Object_Type,
                                 CASE WHEN COUNT(DISTINCT o.Owner)          = 1 THEN LOWER(MAX(o.Owner))   ELSE '< '||COUNT(DISTINCT o.Owner)||' >'          END Root_Blocking_Object_Owner,
                                 CASE WHEN COUNT(DISTINCT o.Object_Name)    = 1 THEN MAX(o.Object_Name)    ELSE '< '||COUNT(DISTINCT o.Object_Name)||' >'    END Root_Blocking_Object,
                                 CASE WHEN COUNT(DISTINCT o.SubObject_Name) = 1 THEN MAX(o.SubObject_Name) ELSE '< '||COUNT(DISTINCT o.SubObject_Name)||' >' END Root_Blocking_SubObject,
                                 CASE WHEN COUNT(DISTINCT o.Object_Name) = 1 THEN   /* Nur anzeigen wenn eindeutig */
                                     MAX(CASE
                                       WHEN o.Object_Name LIKE 'SYS_LOB%%' THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 8, 10)))
                                       WHEN o.Object_Name LIKE 'SYS_IL%%'  THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 7, 10)))
                                     END)
                                 END Root_Blocking_Object_Addition,
                                 CASE WHEN COUNT(DISTINCT o.Data_Object_ID) = 1 THEN MIN(o.Data_Object_ID) ELSE NULL END Data_Object_ID,
                                 CASE WHEN COUNT(DISTINCT Root_Instance_Number) > 1 THEN '< '||COUNT(DISTINCT Root_Instance_Number)||' >' ELSE MIN(TO_CHAR(Root_Instance_Number)) END Root_Instance_Number,
                                 CASE WHEN COUNT(DISTINCT Root_SQL_ID)          > 1 THEN '< '||COUNT(DISTINCT Root_SQL_ID)         ||' >' ELSE MIN(Root_SQL_ID)          END Root_SQL_ID,
                                 CASE WHEN COUNT(DISTINCT u.UserName)           > 1 THEN '< '||COUNT(DISTINCT u.UserName)          ||' >' ELSE MIN(u.UserName)           END Root_UserName,
                                 CASE WHEN COUNT(DISTINCT Root_Event)           > 1 THEN '< '||COUNT(DISTINCT Root_Event)          ||' >' ELSE MIN(Root_Event)           END Root_Event,
                                 CASE WHEN COUNT(DISTINCT Root_Module)          > 1 THEN '< '||COUNT(DISTINCT Root_Module)         ||' >' ELSE MIN(Root_Module)          END Root_Module,
                                 CASE WHEN COUNT(DISTINCT Root_Action)          > 1 THEN '< '||COUNT(DISTINCT Root_Action)         ||' >' ELSE MIN(Root_Action)          END Root_Action,
                                 CASE WHEN COUNT(DISTINCT Root_Program)         > 1 THEN '< '||COUNT(DISTINCT Root_Program)        ||' >' ELSE MIN(Root_Program)         END Root_Program,
                                 MAX(cLevel) MaxLevel,
                                 SUM(CASE WHEN cLevel=1 THEN 1 ELSE 0 END) Sample_Count_Direct
                          FROM   root_sel l
                          LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = l.Root_Real_Current_Object_No
                          LEFT OUTER JOIN DBA_Users u   ON u.User_ID = l.Root_User_ID
                          GROUP BY Root_Blocking_Session, Root_Blocking_Session_SerialNo, Root_Blocking_Session_Status #{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
                         )
       SELECT c.Min_Sample_Time, c.Max_Sample_Time, c.Min_Snap_ID, c.Max_Snap_ID,
              x.Root_Blocking_Session, x.Root_Blocking_Session_SerialNo Root_Blocking_Session_SerialNo,
              x.Root_Blocking_Session_Status #{', x.Root_Blocking_Inst_ID' if get_db_version >= '11.2'},
              x.Root_Blocking_Event, x.Root_Blocking_Module, x.Root_Blocking_Action, x.Root_Blocking_Program, x.Root_Blocking_Program, x.Root_Blocking_SQL_ID, u.UserName Root_Blocking_UserName,
              x.DeadLock, x.Max_Seconds_in_Wait_Total,
              c.Current_File_No, c.Current_Block_No, c.Current_Row_No, c.Data_Object_ID,
              c.Blocked_Sessions_Total, c.Waiting_Instance, c.Blocked_Sessions_Direct, c.Seconds_in_Wait_Sample, c.Root_Blocking_Object_Type, c.Root_Blocking_Object_Owner, c.Root_Blocking_Object, c.Root_Blocking_SubObject, Root_Blocking_Object_Addition, c.Root_Instance_Number,
              c.Root_SQL_ID, c.Root_UserName, c.Root_Event, c.Root_Module, c.Root_Action, c.Root_Program, c.MaxLevel, c.Sample_Count_Direct
       FROM   (
              SELECT Decode(SUM(gr.Is_Cycle_Sum), 0, NULL, 'Y') Deadlock,
                     gr.Root_Blocking_Session, gr.Root_Blocking_Session_SerialNo, gr.Root_Blocking_Session_Status #{', gr.Root_Blocking_Inst_ID' if get_db_version >= '11.2'},
                     MAX(Seconds_in_Wait_Total) Max_Seconds_in_Wait_Total
                     #{if get_db_version >= '11.2'
                         ", CASE WHEN COUNT(DISTINCT NVL(NVL(rh.Event, rh.Session_State), 'INACTIVE')) > 1 THEN '< '||COUNT(DISTINCT NVL(NVL(rh.Event, rh.Session_State), 'INACTIVE')) ||' >' ELSE MIN(NVL(NVL(rh.Event, rh.Session_State), 'INACTIVE')) END Root_Blocking_Event
                          , CASE WHEN COUNT(DISTINCT rh.Module)  > 1 THEN '< '||COUNT(DISTINCT rh.Module)  ||' >' ELSE MIN(rh.Module)  END  Root_Blocking_Module
                          , CASE WHEN COUNT(DISTINCT rh.Action)  > 1 THEN '< '||COUNT(DISTINCT rh.Action)  ||' >' ELSE MIN(rh.Action)  END  Root_Blocking_Action
                          , CASE WHEN COUNT(DISTINCT rh.Program) > 1 THEN '< '||COUNT(DISTINCT rh.Program) ||' >' ELSE MIN(rh.Program) END  Root_Blocking_Program
                          , CASE WHEN COUNT(DISTINCT rh.SQL_ID)  > 1 THEN '< '||COUNT(DISTINCT rh.SQL_ID)  ||' >' ELSE MIN(rh.SQL_ID)  END  Root_Blocking_SQL_ID
                          , MAX(rh.User_ID) Root_Blocking_User_ID /* kann sich eigentlich nicht ändern innerhalb Session */
                         "
                       end
                     }
              FROM   (
                      SELECT  /*+ NO_MERGE */ Root_Snap_ID, Root_Rounded_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_SerialNo,
                             Root_Blocking_Session_Status#{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'}, SUM(Is_Cycle) Is_Cycle_Sum,
                             SUM(Seconds_in_Wait)             Seconds_in_Wait_Total   /* Wartezeit aller geblockten Sessions eines Samples */
                      FROM   root_sel l
                      GROUP BY Root_Snap_ID, Root_Rounded_Sample_Time, Root_Blocking_Session, Root_Blocking_Session_SerialNo, Root_Blocking_Session_Status
                      #{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
                    ) gr
                    CROSS JOIN (SELECT ? DBID FROM DUAL) db
                    #{if get_db_version >= '11.2'
                   "LEFT OUTER JOIN Ash rh ON rh.Instance_Number = gr.Root_Blocking_Inst_ID AND rh.Rounded_Sample_Time = gr.Root_Rounded_Sample_Time AND rh.Session_ID = gr.Root_Blocking_Session
                    WHERE (NOT EXISTS (SELECT /*+ HASH_AJ) */ 1 FROM TSSel i    /* Nur die Knoten ohne Parent-Blocker darstellen */
                                        WHERE  i.Rounded_Sample_Time  = gr.Root_Rounded_Sample_Time
                                        AND    i.Session_ID           = gr.Root_Blocking_Session
                                        AND    i.Session_Serial_No      = gr.Root_Blocking_Session_SerialNo
                                        #{'AND    i.Instance_number      = gr.Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
                                       ) OR Is_Cycle_Sum > 0   /* wenn cycle, dann Existenz eines Samples mit weiterer Referenz auf Blocking Session tolerieren */
                          )
                   "
                      end
                    }
               GROUP BY Root_Blocking_Session, Root_Blocking_Session_SerialNo, Root_Blocking_Session_Status #{', Root_Blocking_Inst_ID' if get_db_version >= '11.2'}
              ) x
       LEFT OUTER JOIN DBA_Users u ON u.User_ID = x.Root_Blocking_User_ID
       JOIN   root_sel_compr c ON  NVL(c.Root_Blocking_Session, 0) = NVL(x.Root_Blocking_Session,0) AND NVL(c.Root_Blocking_Session_SerialNo, 0) = NVL(x.Root_Blocking_Session_SerialNo, 0)
                               AND c.Root_Blocking_Session_Status = x.Root_Blocking_Session_Status #{' AND NVL(c.Root_Blocking_Inst_ID, 0) = NVL(x.Root_Blocking_Inst_ID, 0)' if get_db_version >= '11.2'}
       ORDER BY x.Max_Seconds_in_Wait_Total + Seconds_in_Wait_Sample DESC /* May be that Max_Seconds_in_Wait_Total is 0 evene if waits occurred */
       ", @dbid, @min_snap_id, @max_snap_id, @time_selection_start, @time_selection_end, @dbid]

    render_partial :list_blocking_locks_historic
  end

  def list_blocking_locks_historic_event_dependency
    @dbid = prepare_param_dbid
    @show_instances = prepare_param(:show_instances) == '1'
    save_session_time_selection

    with_sql, with_bindings = blocking_locks_historic_event_with_selection(@dbid, @time_selection_start, @time_selection_end)

    @event_locks = sql_select_iterator ["\
        #{with_sql}
        SELECT b.*,
               Waiting_Active_Seconds / ((Last_Occurrence - First_Occurrence) *86400 +
                                         CASE WHEN Last_Occurrence = First_Occurrence THEN Single_Sample_Cycle ELSE 0 END   /* Add one cycle to prevent div by zero */
                                        )   Avg_Waiting_Sessions,
               ub.UserName            Blocking_User,
               uw.UserName            Waiting_User,
               sb.Service_Name        Blocking_Service,
               sw.Service_Name        Waiting_Service
        FROM   (
                SELECT /*+ NO_MERGE */
                       Blocking_Event,
                       Waiting_Event,
                       #{"Blocking_Instance, Waiting_Instance, " if @show_instances}
                       COUNT(DISTINCT Blocking_Instance||','||Blocking_Session_ID||','||Blocking_Session_Serial_No)   Blocking_Sessions,
                       COUNT(DISTINCT Waiting_Instance||','||Waiting_Session_ID||','||Waiting_Session_Serial_No)     Waiting_Sessions,
                       SUM(Blocking_Active_Seconds)                                         Blocking_Active_Seconds,
                       SUM(Waiting_Active_Seconds)                                          Waiting_Active_Seconds,
                       MIN(Waiting_Active_Seconds)                                          Single_Sample_Cycle,
                       MIN(Waiting_Rounded_Sample_Time)                                     First_Occurrence,
                       MAX(Waiting_Rounded_Sample_Time)                                     Last_Occurrence,
                       MIN(Seconds_In_Wait)                                                 Min_Seconds_In_Wait,
                       MAX(Seconds_In_Wait)                                                 Max_Seconds_In_Wait,
                       AVG(Seconds_In_Wait)                                                 Avg_Seconds_In_Wait,
                       COUNT(*)                                                             Samples,
                       MIN(Snap_ID)                                                         Min_Snap_ID,
                       MAX(Snap_ID)                                                         Max_Snap_ID,
                       CASE WHEN COUNT(DISTINCT Blocking_User_ID)       = 1 THEN MIN(Blocking_User_ID)      END Blocking_User_ID,
                       CASE WHEN COUNT(DISTINCT Waiting_User_ID)        = 1 THEN MIN(Waiting_User_ID)       END Waiting_User_ID,
                       CASE WHEN COUNT(DISTINCT Blocking_Module)        = 1 THEN MIN(Blocking_Module)       END Blocking_Module,
                       CASE WHEN COUNT(DISTINCT Waiting_Module)         = 1 THEN MIN(Waiting_Module)        END Waiting_Module,
                       CASE WHEN COUNT(DISTINCT Blocking_Action)        = 1 THEN MIN(Blocking_Action)       END Blocking_Action,
                       CASE WHEN COUNT(DISTINCT Waiting_Action)         = 1 THEN MIN(Waiting_Action)        END Waiting_Action,
                       CASE WHEN COUNT(DISTINCT Blocking_Machine)       = 1 THEN MIN(Blocking_Machine)      END Blocking_Machine,
                       CASE WHEN COUNT(DISTINCT Waiting_Machine)        = 1 THEN MIN(Waiting_Machine)       END Waiting_Machine,
                       CASE WHEN COUNT(DISTINCT Blocking_Program)       = 1 THEN MIN(Blocking_Program)      END Blocking_Program,
                       CASE WHEN COUNT(DISTINCT Waiting_Program)        = 1 THEN MIN(Waiting_Program)       END Waiting_Program,
                       CASE WHEN COUNT(DISTINCT Blocking_Service_Hash)  = 1 THEN MIN(Blocking_Service_Hash) END Blocking_Service_Hash,
                       CASE WHEN COUNT(DISTINCT Waiting_Service_Hash)   = 1 THEN MIN(Waiting_Service_Hash)  END Waiting_Service_Hash
                FROM   (SELECT /*+ NO_MERGE */
                               CASE WHEN waiters.Blocking_Session_Status = 'GLOBAL'
                               THEN 'GLOBAL (other RAC instance)'
                               ELSE NVL(NVL(blockers.Event, blockers.Session_State), 'IDLE')
                               END                                                                  Blocking_Event,
                               NVL(NVL(waiters.Event,  waiters.Session_State),  'UNKNOWN')          Waiting_Event,
                               blockers.Sample_Cycle                                                Blocking_Active_Seconds,
                               waiters.Sample_Cycle                                                 Waiting_Active_Seconds,
                               waiters.Blocking_Inst_ID                                             Blocking_Instance,
                               waiters.Instance_Number                                              Waiting_Instance,
                               waiters.Blocking_Session                                             Blocking_Session_ID,
                               waiters.Session_ID                                                   Waiting_Session_ID,
                               waiters.Blocking_Session_Serial_No                                   Blocking_Session_Serial_No,
                               waiters.Session_Serial_No                                              Waiting_Session_Serial_No,
                               waiters.Rounded_Sample_Time                                          Waiting_Rounded_Sample_Time,
                               waiters.Time_Waited/1000000                                          Seconds_in_Wait,
                               waiters.Snap_ID,
                               blockers.User_ID                                                     Blocking_User_ID,
                               waiters.User_ID                                                      Waiting_User_ID,
                               blockers.Module                                                      Blocking_Module,
                               waiters.Module                                                       Waiting_Module,
                               blockers.Action                                                      Blocking_Action,
                               waiters.Action                                                       Waiting_Action,
                               blockers.Machine                                                     Blocking_Machine,
                               waiters.Machine                                                      Waiting_Machine,
                               blockers.Program                                                     Blocking_Program,
                               waiters.Program                                                      Waiting_Program,
                               blockers.Service_Hash                                                Blocking_Service_Hash,
                               waiters.Service_Hash                                                 Waiting_Service_Hash
                        FROM   tsSel waiters
                        LEFT OUTER JOIN tsSel blockers ON blockers.Instance_Number = waiters.Blocking_Inst_ID AND blockers.Session_ID = waiters.Blocking_Session
                                                       AND blockers.Session_Serial_No = waiters.Blocking_Session_Serial_No AND blockers.Rounded_Sample_Time = waiters.Rounded_Sample_Time
                        WHERE  waiters.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                       )
                GROUP BY Blocking_Event, Waiting_Event#{", Blocking_Instance, Waiting_Instance" if @show_instances}
               ) b
        LEFT OUTER JOIN All_Users ub ON ub.User_ID = Blocking_User_ID
        LEFT OUTER JOIN All_Users uw ON uw.User_ID = Waiting_User_ID
        LEFT OUTER JOIN DBA_Hist_Service_Name sb  ON sb.DBID = ? AND sb.Service_Name_Hash = Blocking_Service_Hash
        LEFT OUTER JOIN DBA_Hist_Service_Name sw  ON sw.DBID = ? AND sw.Service_Name_Hash = Blocking_Service_Hash
        ORDER BY Waiting_Active_Seconds DESC
       "].concat(with_bindings).concat([@dbid, @dbid])


    render_partial :list_blocking_locks_historic_event_dependency
  end

  def blocking_locks_historic_event_dependency_timechart
    dbid = prepare_param_dbid
    @show_instances = prepare_param(:show_instances) == 'true'
    save_session_time_selection
    group_seconds = require_param(:group_seconds).to_i

    with_sql, with_bindings = blocking_locks_historic_event_with_selection(dbid, @time_selection_start, @time_selection_end)

    singles = sql_select_iterator ["\
      #{with_sql}
      SELECT Start_Sample, Criteria,
             SUM(Sample_Cycle / CASE WHEN Sample_Cycle > #{group_seconds} THEN #{group_seconds}*Sample_Cycle ELSE #{group_seconds} END) Diagram_Value
      FROM   (SELECT TRUNC(waiters.Rounded_Sample_Time) + TRUNC(TO_NUMBER(TO_CHAR(waiters.Rounded_Sample_Time, 'SSSSS'))/#{group_seconds})*#{group_seconds}/86400 Start_Sample,
                     #{"'('||waiters.Instance_Number||') '||" if @show_instances}
                     NVL(NVL(waiters.Event,  waiters.Session_State),  'UNKNOWN') ||
                     ' -> '||
                     #{"'('||waiters.Blocking_Inst_ID||') '||" if @show_instances}
                     CASE WHEN waiters.Blocking_Session_Status = 'GLOBAL'
                     THEN 'GLOBAL (other RAC instance)'
                     ELSE NVL(NVL(blockers.Event, blockers.Session_State), 'IDLE')
                     END Criteria,
                     waiters.Sample_Cycle
              FROM   tsSel waiters
              LEFT OUTER JOIN tsSel blockers ON blockers.Instance_Number = waiters.Blocking_Inst_ID AND blockers.Session_ID = waiters.Blocking_Session
                                             AND blockers.Session_Serial_No = waiters.Blocking_Session_Serial_No AND blockers.Rounded_Sample_Time = waiters.Rounded_Sample_Time
              WHERE  waiters.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
             )
      GROUP BY Start_Sample, Criteria
      ORDER BY Start_Sample
    "].concat(with_bindings)

    top_x = 15
    diagram_caption = "Number of blocked waiting sessions condensed by #{group_seconds} seconds for top-#{top_x} grouped by combination of waiting and blocking events between #{@time_selection_start} and #{@time_selection_end}"

    plot_top_x_diagramm(:data_array         => singles,
                        :time_key_name      => 'start_sample',
                        :curve_key_name     => 'criteria',
                        :value_key_name     => 'diagram_value',
                        :top_x              => top_x,
                        :caption            => diagram_caption,
                        :null_points_cycle  => group_seconds,
                        :update_area        => params[:update_area]
    )

  end

  def blocking_locks_historic_event_detail
    save_session_time_selection
    @dbid               = prepare_param :dbid
    @blocking_instance  = prepare_param :blocking_instance
    @blocking_event     = prepare_param :blocking_event
    @waiting_event      = prepare_param :waiting_event
    @role               = prepare_param(:role).to_sym                               # :blocking or :waiting
    @waiting_instance   = prepare_param :waiting_instance
    @waiting_session    = prepare_param :waiting_session
    @waiting_serial_no   = prepare_param :waiting_serial_no

    with_sql, with_bindings = blocking_locks_historic_event_with_selection(@dbid, @time_selection_start, @time_selection_end)

    session_select = case @role
                     when :blocking then "Blocking_Instance Instance, Blocking_Session_ID SID, Blocking_Session_Serial_No Serial_No"
                     when :waiting  then "Waiting_Instance  Instance, Waiting_Session_ID  SID, Waiting_Session_Serial_No  Serial_No"
                     else raise "blocking_locks_historic_event_detail: unknown role '#{@role}'"
                     end

    groupby = case @role
              when :blocking then "Blocking_Instance, Blocking_Session_ID, Blocking_Session_Serial_No"
              when :waiting  then "Waiting_Instance,  Waiting_Session_ID,  Waiting_Session_Serial_No"
              else raise "blocking_locks_historic_event_detail: unknown role '#{role}'"
              end

    where_string = ''
    where_values = []

    global_where_string = ''
    global_where_values = []

    if @blocking_instance
      if @blocking_instance == 'NULL'
        where_string << " AND waiters.Blocking_Inst_ID IS NULL"
      else
        where_string << " AND waiters.Blocking_Inst_ID = ?"
        where_values << @blocking_instance
      end
    end

    if @waiting_instance
      where_string << " AND waiters.Instance_Number = ?"
      where_values << @waiting_instance
    end

    if @waiting_session
      where_string << " AND waiters.Session_ID = ?"
      where_values << @waiting_session
    end

    if @waiting_serial_no
      where_string << " AND waiters.Session_Serial_No = ?"
      where_values << @waiting_serial_no
    end

    global_where_string << " Blocking_Event = ?"
    global_where_values << @blocking_event

    global_where_string << " AND Waiting_Event = ?"
    global_where_values << @waiting_event

    @sessions = sql_select_iterator ["\
      #{with_sql}
      SELECT b.*,
             Waiting_Active_Seconds / ((Last_Occurrence - First_Occurrence) *86400 +
                                       CASE WHEN Last_Occurrence = First_Occurrence THEN Single_Sample_Cycle ELSE 0 END   /* Add one cycle to prevent div by zero */
                                      )   Avg_Waiting_Sessions,
             ub.UserName            Blocking_User,
             uw.UserName            Waiting_User,
             sb.Service_Name        Blocking_Service,
             sw.Service_Name        Waiting_Service
      FROM   (
              SELECT #{session_select},
                     MIN(Waiting_Rounded_Sample_Time) First_Occurrence,
                     MAX(Waiting_Rounded_Sample_Time) Last_Occurrence,
                     MIN(Snap_ID)                     Min_Snap_ID,
                     MAX(Snap_ID)                     Max_Snap_ID,
                     COUNT(*)                         Samples,
                     COUNT(DISTINCT Blocking_Instance||','||Blocking_Session_ID||','||Blocking_Session_Serial_No)   Blocking_Sessions,
                     COUNT(DISTINCT Waiting_Instance ||','||Waiting_Session_ID ||','||Waiting_Session_Serial_No )   Waiting_Sessions,
                     SUM(Blocking_Active_Seconds)                                         Blocking_Active_Seconds,
                     SUM(Waiting_Active_Seconds)                                          Waiting_Active_Seconds,
                     MIN(Waiting_Active_Seconds)                                          Single_Sample_Cycle,
                     MIN(Seconds_In_Wait)                                                 Min_Seconds_In_Wait,
                     MAX(Seconds_In_Wait)                                                 Max_Seconds_In_Wait,
                     AVG(Seconds_In_Wait)                                                 Avg_Seconds_In_Wait,
                     CASE WHEN COUNT(DISTINCT Blocking_User_ID)       = 1 THEN MIN(Blocking_User_ID)      END Blocking_User_ID,
                     CASE WHEN COUNT(DISTINCT Waiting_User_ID)        = 1 THEN MIN(Waiting_User_ID)       END Waiting_User_ID,
                     CASE WHEN COUNT(DISTINCT Blocking_Module)        = 1 THEN MIN(Blocking_Module)       END Blocking_Module,
                     CASE WHEN COUNT(DISTINCT Waiting_Module)         = 1 THEN MIN(Waiting_Module)        END Waiting_Module,
                     CASE WHEN COUNT(DISTINCT Blocking_Action)        = 1 THEN MIN(Blocking_Action)       END Blocking_Action,
                     CASE WHEN COUNT(DISTINCT Waiting_Action)         = 1 THEN MIN(Waiting_Action)        END Waiting_Action,
                     CASE WHEN COUNT(DISTINCT Blocking_Machine)       = 1 THEN MIN(Blocking_Machine)      END Blocking_Machine,
                     CASE WHEN COUNT(DISTINCT Waiting_Machine)        = 1 THEN MIN(Waiting_Machine)       END Waiting_Machine,
                     CASE WHEN COUNT(DISTINCT Blocking_Program)       = 1 THEN MIN(Blocking_Program)      END Blocking_Program,
                     CASE WHEN COUNT(DISTINCT Waiting_Program)        = 1 THEN MIN(Waiting_Program)       END Waiting_Program,
                     CASE WHEN COUNT(DISTINCT Blocking_Service_Hash)  = 1 THEN MIN(Blocking_Service_Hash) END Blocking_Service_Hash,
                     CASE WHEN COUNT(DISTINCT Waiting_Service_Hash)   = 1 THEN MIN(Waiting_Service_Hash)  END Waiting_Service_Hash
              FROM   (SELECT/*+ NO_MERGE */
                            CASE WHEN waiters.Blocking_Session_Status = 'GLOBAL'
                            THEN 'GLOBAL (other RAC instance)'
                            ELSE NVL(NVL(blockers.Event, blockers.Session_State), 'IDLE')
                            END                                                                  Blocking_Event,
                            NVL(NVL(waiters.Event,  waiters.Session_State),  'UNKNOWN')          Waiting_Event,
                            blockers.Sample_Cycle                                                Blocking_Active_Seconds,
                            waiters.Sample_Cycle                                                 Waiting_Active_Seconds,
                            waiters.Blocking_Inst_ID                                             Blocking_Instance,
                            waiters.Instance_Number                                              Waiting_Instance,
                            waiters.Blocking_Session                                             Blocking_Session_ID,
                            waiters.Session_ID                                                   Waiting_Session_ID,
                            waiters.Blocking_Session_Serial_No                                     Blocking_Session_Serial_No,
                            waiters.Session_Serial_No                                              Waiting_Session_Serial_No,
                            waiters.Rounded_Sample_Time                                          Waiting_Rounded_Sample_Time,
                            waiters.Time_Waited/1000000                                          Seconds_in_Wait,
                            waiters.Snap_ID                                                      Snap_ID,
                            blockers.User_ID                                                     Blocking_User_ID,
                            waiters.User_ID                                                      Waiting_User_ID,
                            blockers.Module                                                      Blocking_Module,
                            waiters.Module                                                       Waiting_Module,
                            blockers.Action                                                      Blocking_Action,
                            waiters.Action                                                       Waiting_Action,
                            blockers.Machine                                                     Blocking_Machine,
                            waiters.Machine                                                      Waiting_Machine,
                            blockers.Program                                                     Blocking_Program,
                            waiters.Program                                                      Waiting_Program,
                            blockers.Service_Hash                                                Blocking_Service_Hash,
                            waiters.Service_Hash                                                 Waiting_Service_Hash
                      FROM   tsSel waiters
                      LEFT OUTER JOIN tsSel blockers ON blockers.Instance_Number = waiters.Blocking_Inst_ID AND blockers.Session_ID = waiters.Blocking_Session
                                                     AND blockers.Session_Serial_No = waiters.Blocking_Session_Serial_No AND blockers.Rounded_Sample_Time = waiters.Rounded_Sample_Time
                      WHERE  waiters.Blocking_Session_Status IN ('VALID', 'GLOBAL') /* Session wartend auf Blocking-Session */
                      #{where_string}
                     )
              WHERE  #{global_where_string}
              GROUP BY #{groupby}
             ) b
     LEFT OUTER JOIN All_Users ub ON ub.User_ID = Blocking_User_ID
     LEFT OUTER JOIN All_Users uw ON uw.User_ID = Waiting_User_ID
     LEFT OUTER JOIN DBA_Hist_Service_Name sb  ON sb.DBID = ? AND sb.Service_Name_Hash = Blocking_Service_Hash
     LEFT OUTER JOIN DBA_Hist_Service_Name sw  ON sw.DBID = ? AND sw.Service_Name_Hash = Blocking_Service_Hash
     ORDER BY Waiting_Active_Seconds DESC
    "].concat(with_bindings).concat(where_values).concat(global_where_values).concat([@dbid, @dbid])

    render_partial
  end

  def list_blocking_locks_historic_detail
    @dbid = prepare_param_dbid
    save_session_time_selection
    @min_snap_id                = params[:min_snap_id]
    @max_snap_id                = params[:max_snap_id]
    @min_sample_time            = params[:min_sample_time]
    @max_sample_time            = params[:max_sample_time]

    @blocking_instance          = prepare_param :blocking_instance
    @blocking_session           = prepare_param :blocking_session
    @blocking_session_serial_no = prepare_param :blocking_session_serial_no

    wherevalues = [ @dbid, @min_snap_id, @max_snap_id, @min_sample_time , @max_sample_time ]
    wherevalues << @blocking_session            if @blocking_session
    wherevalues << @blocking_session_serial_no  if @blocking_session
    wherevalues << @blocking_instance           if @blocking_session && get_db_version >= '11.2'
    wherevalues << @blocking_session            if @blocking_session
    wherevalues << @blocking_session_serial_no  if @blocking_session
    wherevalues << @blocking_instance           if @blocking_session && get_db_version >= '11.2'

    @locks = sql_select_iterator [
        "WITH /* Panorama-Tool Ramm */
         #{ash_select(awr_filter: "DBID = ? AND Snap_ID BETWEEN ? AND ?",
                      global_filter: "       Rounded_Sample_Time >= TO_DATE(?, '#{sql_datetime_second_mask}')      /* auf eine Sekunde genau gerundete Zeit */
                                      AND    Rounded_Sample_Time <= TO_DATE(?, '#{sql_datetime_second_mask}')      /* auf eine Sekunde genau gerundete Zeit */
                                      AND    Blocking_Session_Status IN ('VALID', 'GLOBAL') -- Session wartend auf Blocking-Session",
                      select_rounded_sample_time: true,
                      with_cte_alias: 'TSel'
                     )},
        -- Komplette Menge der Lock-Beziehungen dieser Blocking-Session
        root_sel as (SELECT CONNECT_BY_ROOT Instance_Number         Root_Instance_Number,
                            CONNECT_BY_ROOT Session_ID              Root_Session_ID,
                            CONNECT_BY_ROOT Session_Serial_No         Root_Session_Serial_No,
                            CONNECT_BY_ROOT Blocking_Session_Status Root_Blocking_Session_Status,
                            CONNECT_BY_ROOT (CASE WHEN l.P2Text = 'object #' THEN /* Wait kennt Object */ l.P2 ELSE l.Current_Obj_No END) Root_Real_Current_Object_No,
                            LEVEL cLevel,
                            Connect_By_IsCycle Is_Cycle,
                            l.*
                     FROM   tSel l
                     CONNECT BY NOCYCLE PRIOR Rounded_Sample_Time = Rounded_Sample_Time
                                    AND PRIOR Session_ID      = Blocking_Session
                                    AND PRIOR Session_Serial_No = Blocking_Session_Serial_No
                                 #{'AND PRIOR Instance_number = Blocking_Inst_ID' if get_db_version >= '11.2'}
                     START WITH #{@blocking_session ? "Blocking_Session = ? AND Blocking_Session_Serial_No = ? #{' AND Blocking_Inst_ID = ?' if get_db_version >= '11.2'}" : "Blocking_Session_Status='GLOBAL'"}
                    ),
        -- Komplette Menge der Lock-Beziehungen verdichtet nach direkten Sessions
        root_sel_compr as (SELECT Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No,
                                  COUNT(DISTINCT CASE WHEN cLevel>1 THEN Session_ID END) Blocked_Sessions_Total,
                                  MAX(           CASE WHEN cLevel>1 THEN Session_ID END) Max_Blocked_Session_Total,
                                  COUNT(DISTINCT CASE WHEN cLevel=2 THEN Session_ID ELSE NULL END) Blocked_Sessions_Direct,
                                  MAX(           CASE WHEN cLevel=2 THEN Session_ID END) Max_Blocked_Session_Direct,
                                  SUM(CASE WHEN cLevel=1 THEN 1 ELSE 0 END) Sample_Count_Direct,
                                  #{ 'CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 1 THEN Current_File_No  END) = 1 THEN MAX(CASE WHEN cLevel = 1 THEN Current_File_No   END) ELSE NULL END Blocking_File_No,
                                      CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 1 THEN Current_Block_No END) = 1 THEN MIN(CASE WHEN cLevel = 1 THEN Current_Block_No  END) ELSE NULL END Blocking_Block_No,
                                      CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 1 THEN Current_Row_No   END) = 1 THEN MIN(CASE WHEN cLevel = 1 THEN Current_Row_No    END) ELSE NULL END Blocking_Row_No,
                                      CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Current_File_No  END) = 1 THEN MAX(CASE WHEN cLevel = 2 THEN Current_File_No   END) ELSE NULL END Blocked_File_No,
                                      CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Current_Block_No END) = 1 THEN MIN(CASE WHEN cLevel = 2 THEN Current_Block_No  END) ELSE NULL END Blocked_Block_No,
                                      CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Current_Row_No   END) = 1 THEN MIN(CASE WHEN cLevel = 2 THEN Current_Row_No    END) ELSE NULL END Blocked_Row_No,
                                     ' if get_db_version >= '11.2'
                                  }
                                  SUM(CASE WHEN CLevel>1 THEN Sample_Cycle ELSE 0 END) Seconds_in_Wait_Blocked_Sample,
                                  CASE WHEN COUNT(DISTINCT o.Object_Type)    = 1 THEN MAX(o.Object_Type)                                                      END Root_Blocking_Object_Type,
                                  CASE WHEN COUNT(DISTINCT o.Owner)          = 1 THEN LOWER(MAX(o.Owner))   ELSE '< '||COUNT(DISTINCT o.Owner)||' >'          END Root_Blocking_Object_Owner,
                                  CASE WHEN COUNT(DISTINCT o.Object_Name)    = 1 THEN MAX(o.Object_Name)    ELSE '< '||COUNT(DISTINCT o.Object_Name)||' >'    END Root_Blocking_Object,
                                  CASE WHEN COUNT(DISTINCT o.SubObject_Name) = 1 THEN MAX(o.SubObject_Name) ELSE '< '||COUNT(DISTINCT o.SubObject_Name)||' >' END Root_Blocking_SubObject,
                                  CASE WHEN COUNT(DISTINCT o.Object_Name)    = 1 THEN   /* Nur anzeigen wenn eindeutig */
                                      MAX(CASE
                                        WHEN o.Object_Name LIKE 'SYS_LOB%%' THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 8, 10)))
                                        WHEN o.Object_Name LIKE 'SYS_IL%%'  THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(o.Object_Name, 7, 10)))
                                      END)
                                  END Root_Blocking_Object_Addition,
                                  CASE WHEN COUNT(DISTINCT ob.Object_Type)    = 1 THEN MAX(ob.Object_Type)                                                       END Blocked_Object_Type,
                                  CASE WHEN COUNT(DISTINCT ob.Owner)          = 1 THEN LOWER(MAX(ob.Owner))   ELSE '< '||COUNT(DISTINCT ob.Owner)||' >'          END Blocked_Object_Owner,
                                  CASE WHEN COUNT(DISTINCT ob.Object_Name)    = 1 THEN MAX(ob.Object_Name)    ELSE '< '||COUNT(DISTINCT ob.Object_Name)||' >'    END Blocked_Object,
                                  CASE WHEN COUNT(DISTINCT ob.SubObject_Name) = 1 THEN MAX(ob.SubObject_Name) ELSE '< '||COUNT(DISTINCT ob.SubObject_Name)||' >' END Blocked_SubObject,
                                  CASE WHEN COUNT(DISTINCT ob.Object_Name)    = 1 THEN   /* Nur anzeigen wenn eindeutig */
                                      MAX(CASE
                                        WHEN ob.Object_Name LIKE 'SYS_LOB%%' THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ob.Object_Name, 8, 10)))
                                        WHEN ob.Object_Name LIKE 'SYS_IL%%'  THEN (SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(ob.Object_Name, 7, 10)))
                                      END)
                                  END Blocked_Object_Addition,
                                  CASE WHEN COUNT(DISTINCT o. Data_Object_ID) = 1 THEN MAX(o.Data_Object_ID)  ELSE NULL END Blocking_Data_Object_ID,
                                  CASE WHEN COUNT(DISTINCT ob.Data_Object_ID) = 1 THEN MAX(ob.Data_Object_ID) ELSE NULL END Blocked_Data_Object_ID,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Instance_Number END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Instance_Number END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN TO_CHAR(Instance_Number) END) END Blocked_Instance,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN u.UserName      END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN u.UserName      END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN u.UserName               END) END Blocked_UserName,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN SQL_ID          END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN SQL_ID          END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN SQL_ID                   END) END Blocked_SQL_ID,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Event           END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Event           END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN Event                    END) END Blocked_Event,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Module          END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Module          END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN Module                   END) END Blocked_Module,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Action          END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Action          END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN Action                   END) END Blocked_Action,
                                  CASE WHEN COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Program         END) > 1 THEN  '< '||COUNT(DISTINCT CASE WHEN cLevel = 2 THEN Program         END)||' >' ELSE MAX(CASE WHEN cLevel = 2 THEN Program                  END) END Blocked_Program,
                                 MAX(cLevel)-1 MaxLevel
                           FROM   root_sel l
                           LEFT OUTER JOIN DBA_Objects o  ON  o.Object_ID = Root_Real_Current_Object_No
                           LEFT OUTER JOIN DBA_Objects ob ON ob.Object_ID = CASE WHEN cLevel = 2 THEN CASE WHEN P2Text = 'object #' THEN /* Wait kennt Object */ P2 ELSE Current_Obj_No END END  /* Unmittelbar geblocktes Objekt */
                           LEFT OUTER JOIN DBA_Users u   ON u.User_ID = l.User_ID
                           GROUP BY Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No
                          ),
        -- Menge der direkten Sessions verdichtet über Zeit
        dir_sel as (SELECT Instance_Number, Session_ID, Session_Serial_No,
                           MIN(Rounded_Sample_Time)-(MAX(Sample_Cycle)/86400)   Min_Sample_Time,                        /* wegen Nachfolgendem BETWEEN-Vergleich der gerundeten Zeiten auf vorherigen Sample_Cycle abgrenzen */
                           MAX(Rounded_Sample_Time)+(MIN(Sample_Cycle)/86400)   Max_Sample_Time,                        /* wegen Nachfolgendem BETWEEN-Vergleich der gerundeten Zeiten auf nächsten Sample_Cycle abgrenzen */
                           MIN(Snap_ID)                                         Min_Snap_ID,
                           MAX(Snap_ID)                                         Max_Snap_ID,
                           MAX(Time_Waited/1000000)               Max_Seconds_in_Wait,      /* max. Wartezeit der geblockten Session innerhalb Zeitraum */
                           SUM(Sample_Cycle)                      Seconds_in_Wait_Sample,   /* Wartezeit auf Basis der anzahl ASH-Samples */
                           MIN(User_ID)                           User_ID,                   /* bleit identisch innerhalb einer Session */
                           CASE WHEN COUNT(DISTINCT SQL_ID)  > 1 THEN '< '||COUNT(DISTINCT SQL_ID)  ||' >' ELSE MIN(SQL_ID)  END SQL_ID,
                           CASE WHEN COUNT(DISTINCT Event)   > 1 THEN '< '||COUNT(DISTINCT Event)   ||' >' ELSE MIN(Event)   END Event,
                           CASE WHEN COUNT(DISTINCT Module)  > 1 THEN '< '||COUNT(DISTINCT Module)  ||' >' ELSE MIN(Module)  END Module,
                           CASE WHEN COUNT(DISTINCT Action)  > 1 THEN '< '||COUNT(DISTINCT Action)  ||' >' ELSE MIN(Action)  END Action,
                           CASE WHEN COUNT(DISTINCT Program) > 1 THEN '< '||COUNT(DISTINCT Program) ||' >' ELSE MIN(Program) END Program
                    FROM   tSel
                    WHERE  #{@blocking_session ? "Blocking_Session = ? AND Blocking_Session_Serial_No = ? #{' AND Blocking_Inst_ID = ?' if get_db_version >= '11.2'}" : "Blocking_Session_Status='GLOBAL'"}
                    GROUP BY Instance_Number, Session_ID, Session_Serial_No
                   )
        SELECT Session_Serial_No, u.UserName,
               o.*,
               o.Max_Seconds_in_Wait          Max_Seconds_In_Wait_Direct,
               o.Seconds_in_Wait_Sample       Seconds_in_Wait_Sample_Direct,
               c.Blocked_Sessions_Total,      c.Max_Blocked_Session_Total,
               c.Blocked_Sessions_Direct,     c.Max_Blocked_Session_Direct,
               c.Seconds_in_Wait_Blocked_Sample,
               c.Root_Blocking_Object_Type, c.Root_Blocking_Object_Owner, c.Root_Blocking_Object, c.Root_Blocking_SubObject, c.Root_Blocking_Object_Addition,
               c.Blocked_Object_Type,       c.Blocked_Object_Owner,       c.Blocked_Object,       c.Blocked_SubObject,       c.Blocked_Object_Addition,
               c.Blocking_Data_Object_ID, c.Blocked_Data_Object_ID,
               c.Blocking_File_No, c.Blocking_Block_No, c.Blocking_Row_No,
               c.Blocked_File_No,  c.Blocked_Block_No,  c.Blocked_Row_No,
               c.Sample_Count_Direct, c.MaxLevel,
               c.Blocked_Instance, c.Blocked_UserName, c.Blocked_SQL_ID, c.Blocked_Event, c.Blocked_Module, c.Blocked_Action, c.Blocked_Program,
               cs.*
        FROM   dir_sel o
        JOIN   (-- Alle gelockten Sessions incl. mittelbare
                SELECT Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No, Root_Blocking_Session_Status, DECODE(SUM(Sum_Is_Cycle), 0, NULL, 'Y') Deadlock,
                       MAX(Seconds_in_Wait_Blocked_Total) Max_Sec_in_Wait_Blocked_Total
                FROM   (SELECT Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No, Root_Blocking_Session_Status,
                               SUM(CASE WHEN CLevel>1 THEN Time_Waited/1000000 ELSE 0 END) Seconds_in_Wait_Blocked_Total,
                               SUM(Is_Cycle) Sum_Is_Cycle
                        FROM   root_sel
                        GROUP BY Rounded_Sample_Time, Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No, Root_Blocking_Session_Status
                       )
                GROUP BY Root_Instance_Number, Root_Session_ID, Root_Session_Serial_No, Root_Blocking_Session_Status
                ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_Session_ID = o.Session_ID AND cs.Root_Session_Serial_No = o.Session_Serial_No
        JOIN    root_sel_compr c ON c.Root_Instance_Number = cs.Root_Instance_Number AND c.Root_Session_ID = cs.Root_Session_ID AND c.Root_Session_Serial_No = cs.Root_Session_Serial_No
        LEFT OUTER JOIN DBA_Users u   ON u.User_ID = o.User_ID
        ORDER BY o.Max_Seconds_in_Wait + o.Seconds_in_Wait_Sample + cs.Max_Sec_in_Wait_Blocked_Total + c.Seconds_in_Wait_Blocked_Sample DESC"].concat(wherevalues)


    render_partial
  end

  def list_ash_dependency_thread
    @blocked_inst_id           = prepare_param(:blocked_inst_id)
    @blocked_session           = params[:blocked_session]
    @blocked_session_serial_no = params[:blocked_session_serial_no]
    @sample_time               = params[:sample_time]
    @min_snap_id               = params[:min_snap_id]
    @max_snap_id               = params[:max_snap_id]

    record_modifier = proc{|rec|
      rec['sql_operation'] = translate_opcode(rec.sql_opcode)
    }

    @thread = sql_select_all(["\
      WITH procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures),
      #{ash_select(awr_filter: "DBID = ? AND Snap_ID BETWEEN ? AND ?
                                AND #{rounded_sample_time_sql(10)} = #{rounded_sample_time_sql(10, "TO_DATE(?, '#{sql_datetime_second_mask}')")} /* compare rounded to 10 seconds */",
                   sga_filter: "#{rounded_sample_time_sql(1)} = TO_DATE(?, '#{sql_datetime_second_mask}')      /* auf eine Sekunde genau gerundete Zeit */",
                   select_rounded_sample_time: true,
                   with_cte_alias: 'TSel'
                  )}
      SELECT x.*, u.UserName, o.Owner, o.Object_Name, o.SubObject_Name, o.Data_Object_ID, f.File_Name, f.Tablespace_Name,
             peo.Owner peo_Owner, peo.Object_Type peo_Object_Type, peo.Object_Name peo_Object_Name, peo.Procedure_Name peo_Procedure_Name,
             po.Owner  po_Owner,  po.Object_Type  po_Object_Type,  po.Object_Name  po_Object_Name,  po.Procedure_Name  po_Procedure_Name,
             sv.Service_Name
      FROM   (SELECT Level Order_Level, CONNECT_BY_ISCYCLE, tSel.*
              FROM   tSel
              CONNECT BY NOCYCLE PRIOR Blocking_Session           = Session_ID
                             AND PRIOR Blocking_Session_Serial_No = Session_Serial_No
                          #{'AND PRIOR Blocking_Inst_ID           = Instance_number ' if get_db_version >= '11.2'}
              START WITH Session_ID = ? AND Session_Serial_No = ? #{" AND Instance_Number = ?" if @blocked_inst_id}
             ) x
       LEFT JOIN All_Users u ON u.User_ID = x.User_ID
       LEFT OUTER JOIN DBA_Objects o   ON o.Object_ID = CASE WHEN x.P2Text = 'object #' THEN /* Wait kennt Object */ x.P2 ELSE x.Current_Obj_No END
       LEFT OUTER JOIN procs peo ON peo.Object_ID = x.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = x.PLSQL_Entry_SubProgram_ID
       LEFT OUTER JOIN procs po  ON po.Object_ID = x.PLSQL_Object_ID        AND po.SubProgram_ID = x.PLSQL_SubProgram_ID
       LEFT OUTER JOIN DBA_Hist_Service_Name sv ON sv.DBID = ? AND sv.Service_Name_Hash = x.Service_Hash
       LEFT OUTER JOIN DBA_Data_Files f ON f.File_ID = x.Current_File_No
       ORDER BY x.Order_Level
      ", get_dbid, @min_snap_id, @max_snap_id, @sample_time, @sample_time, @sample_time, @blocked_session, @blocked_session_serial_no].
        concat(@blocked_inst_id ? [@blocked_inst_id] : []).concat([get_dbid]), record_modifier)

    render_partial
  end

  def show_temp_usage_historic
    @temp_tablespaces = sql_select_all "SELECT Tablespace_Name FROM DBA_Tablespaces WHERE Contents = 'TEMPORARY'"
    render_partial
  end

  # Einstieg aus show_temp_usage_historic
  def first_list_temp_usage_historic
    save_session_time_selection
    @instance = prepare_param_instance
    @temp_ts = prepare_param :temp_ts
    params[:groupfilter] = {}

    params[:groupfilter][:DBID]                  = prepare_param_dbid
    params[:groupfilter][:Instance]              =  @instance if @instance
    # params[:groupfilter][:Idle_Wait1]            = 'PX Deq Credit: send blkd'    # Sessions in idle wait should be considered for TEMP usage
    params[:groupfilter][:time_selection_start]  = @time_selection_start
    params[:groupfilter][:time_selection_end]    = @time_selection_end
    params[:groupfilter][:Temp_TS]               = @temp_ts if @temp_ts

    list_temp_usage_historic    # weiterleitung Event
  end



  def list_temp_usage_historic                                                  # Methode kann nur ab Version 11.2 aufgerufen werden
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]                                         # identische DBID verwenden wie im groupfilter bereits gesetzt

    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    @fuzzy_seconds = params[:fuzzy_seconds].to_i                                # Unscharfe Aufnahme der Max-Werte je Sessions +- x Sekunden
    # Fest vergleichbaren Wert für Hash-Join mitgeben, damit nicht komplette Menge kartesisch verknüpft werden vor Wirken der >= and <= Bedingung
    fuzzy_round_filter = "ROUND(s.Sample_Time, 'HH') = ROUND(t.Sample_Time, 'HH')"  # Unschärfe bei Betrachtung über Stundengrenze wird billigend in Kauf genommen, damit kartesisches Produkt nur innerhalb einer Stunde entsteht

    # Unbrauchbare Funktion, da Übergänge unsauber werden
    #fuzzy_round_filter = "ROUND(TO_NUMBER(TO_CHAR(t.Sample_Time, 'SSSSS')) / (2*#{@fuzzy_seconds} )) =
    #                      ROUND(TO_NUMBER(TO_CHAR(s.Sample_Time, 'SSSSS')) / (2*#{@fuzzy_seconds} ))"

    #fuzzy_round_filter = "ROUND(s.Sample_Time, 'MI') = ROUND(t.Sample_Time, 'MI')"  if @fuzzy_seconds <= 30
    fuzzy_round_filter = "s.Sample_Time = t.Sample_Time"                            if @fuzzy_seconds == 0        # Direkter Vergleich der Werte wenn keine fuzzy-Funktion gewünscht

    case @time_groupby.to_sym
      when :second then group_by_value = "CAST(s.Sample_Time AS DATE)"
      when :minute then group_by_value = "TRUNC(s.Sample_Time, 'MI')"
      when :hour   then group_by_value = "TRUNC(s.Sample_Time, 'HH24')"
      when :day    then group_by_value = "TRUNC(s.Sample_Time)"
      when :week   then group_by_value = "TRUNC(s.Sample_Time, 'WW')"
      else
        raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    # All möglichen Tabellen gejoint, da Filter diese referenzieren können
    @result= sql_select_iterator ["WITH
      #{"procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)," if  @global_where_string['peo.'] ||  @global_where_string['po.']}
      #{ash_select(awr_filter: @dba_hist_where_string,
                   sga_filter: @sga_ash_where_string,
                   global_filter: "Temp_Space_Allocated > 0",
                   with_cte_alias: 'ash',
                   dbid: @dbid
      )},
      samples AS (
        SELECT
               CAST (Sample_Time AS DATE) Sample_Time,
               s.Instance_Number, s.Session_ID, s.Session_Serial_No,
               s.Sample_Cycle,                -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
               s.Temp_Space_Allocated         -- eigentlich nichtssagend, da Summe über alle Sample-Zeiten hinweg, nur benutzt fuer AVG
        FROM   ash s
        #{"LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END" if @global_where_string['o.']}
                            #{"LEFT OUTER JOIN DBA_Users             u   ON u.User_ID   = s.User_ID" if @global_where_string['u.']}
                            #{"LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID" if @global_where_string['peo.']}
                            #{"LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID" if @global_where_string['po.']}
                            #{"LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash" if @global_where_string['sv.']}
                            #{"LEFT OUTER JOIN DBA_Data_Files        f   ON f.File_ID = s.Current_File_No" if @global_where_string['f.']}
        WHERE  1=1
        #{@global_where_string}
      )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             MIN(s.Sample_Time)   Start_Sample_Time,
             MAX(s.Sample_Time)   End_Sample_Time,
             SUM(Sample_Count)    Sample_Count,
             SUM(Time_Waited_Secs) Time_Waited_Secs,
             MAX(s.Sum_Temp_Space_Allocated)/(1024*1024)                      Max_Sum_Temp_Space_Allocated,
             MAX(s.Sum_Temp_Floating)/(1024*1024 )                            Max_Sum_Temp_Floating,
             MAX(s.Max_Temp_Space_Alloc_per_Sess)/(1024*1024)                 Max_Temp_Space_Alloc_per_Sess,
             SUM(s.Sum_Temp_Space_Allocated)/SUM(s.Sample_Count)/(1024*1024)  Avg_Temp_Space_Alloc_per_Sess
      FROM   (SELECT Sample_Time,
                     SUM(Sample_Count)      Sample_Count,                       -- Summation über die Sessions des Samples
                     SUM(Time_Waited_Secs)  Time_Waited_Secs,                   -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
                     SUM(Temp_Exact)        Sum_Temp_Space_Allocated,           -- Summation über die Sessions des Samples
                     SUM(Temp_Floating)     Sum_Temp_Floating,                  -- Summation über die Sessions des Samples
                     MAX(Temp_Exact)        Max_Temp_Space_Alloc_per_Sess       -- Max. Wert einer Session des Samples
              FROM   (SELECT Sample_Time,
                             MAX(Sample_Count)      Sample_Count,
                             MAX(Time_Waited_Secs)  Time_Waited_Secs,
                             MAX(Temp_Exact)        Temp_Exact,                 -- Temp je Session zum Zeitpunkt des Samples
                             MAX(Temp_Floating)     Temp_Floating               -- Max. Temp je Session zum Zeitpunkt +- x Sekunden
                      FROM   (SELECT /*+ NO_MERGE ORDERED */
                                     t.Sample_Time,                   -- Jede vorkommende Sample_Time verknüpft mit Samples vorher und nachher
                                     s.Instance_Number, s.Session_ID, s.Session_Serial_No,  -- Attribute der verknüpften Sessions
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN 1 ELSE 0 END                                                      Sample_Count,
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN ss.Sample_Cycle ELSE 0 END                                        Time_Waited_Secs, -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN ss.Temp_Space_Allocated ELSE 0 END                                Temp_Exact,       -- konkreter Wert zu t.sample_Time
                                     MAX(NVL(ss.Temp_Space_Allocated, 0)) OVER (PARTITION BY s.Instance_Number, s.Session_ID, s.Session_Serial_No, s.sample_Time)  Temp_Floating     -- Max. Wert je Session zu t.sample_Time +- x Sekunden
                              FROM   (SELECT /*+ NO_MERGE */ DISTINCT Instance_Number, Sample_Time FROM Samples) t
                              JOIN   (SELECT /*+ NO_MERGE */ Sample_Time, Instance_Number, Session_ID, Session_Serial_No FROM Samples) s ON  s.Instance_Number = t.Instance_Number
                                                                                                                                         AND t.Sample_Time >= s.Sample_Time - INTERVAL '#{@fuzzy_seconds}' SECOND AND t.Sample_Time <= s.Sample_Time + INTERVAL '#{@fuzzy_seconds}' SECOND
                                                                                                                                         #{ " AND #{fuzzy_round_filter}" if fuzzy_round_filter}
                              LEFT OUTER JOIN Samples ss ON ss.Sample_Time = t.Sample_Time AND ss.Instance_Number = s.Instance_Number AND ss.Session_ID = s.Session_ID AND ss.Session_Serial_No = s.Session_Serial_No
                             )
                      GROUP BY Sample_Time, Instance_Number, Session_ID, Session_Serial_No  -- Verdichten des mit +/- x Sekunden ausmultiplizierten Ergebnis zurück auf reale Menge
                     )
              GROUP BY Sample_Time     -- Auf Ebene eines Samples reduzieren ueber RAC-Instanzen hinweg
             ) s
      WHERE  s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(@groupfilter[:time_selection_start])}')    -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      AND    s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(@groupfilter[:time_selection_end])}')      -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
      "].concat(@dba_hist_where_values).concat(@sga_ash_where_values).concat(@global_where_values).concat([@groupfilter[:time_selection_start], @groupfilter[:time_selection_end]])

    @total_temp_mb = sql_select_one ["SELECT SUM(Bytes)/(1024*1024) FROM DBA_Temp_Files#{" WHERE Tablespace_Name = ?" if @groupfilter[:Temp_TS] }",
                                    ].concat(@groupfilter[:Temp_TS] ? [@groupfilter[:Temp_TS]] : [])

    render_partial :list_temp_usage_historic
  end

  # Einstieg aus show_pga_usage_historic
  def first_list_pga_usage_historic
    save_session_time_selection
    @instance = prepare_param_instance
    params[:groupfilter] = {}

    params[:groupfilter][:DBID]                  = prepare_param_dbid
    params[:groupfilter][:Instance]              =  @instance if @instance
    # params[:groupfilter][:Idle_Wait1]            = 'PX Deq Credit: send blkd'    # Sessions in idle wait should be considered for TEMP usage
    params[:groupfilter][:time_selection_start]  = @time_selection_start
    params[:groupfilter][:time_selection_end]    = @time_selection_end

    list_pga_usage_historic    # weiterleitung Event
  end

  def list_pga_usage_historic                                                  # Methode kann nur ab Version 11.2 aufgerufen werden
    where_from_groupfilter(params[:groupfilter], nil)
    @dbid = params[:groupfilter][:DBID]                                         # identische DBID verwenden wie im groupfilter bereits gesetzt

    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]

    @fuzzy_seconds = params[:fuzzy_seconds].to_i                                # Unscharfe Aufnahme der Max-Werte je Sessions +- x Sekunden
    # Fest vergleichbaren Wert für Hash-Join mitgeben, damit nicht komplette Menge kartesisch verknüpft werden vor Wirken der >= and <= Bedingung
    fuzzy_round_filter = "ROUND(s.Sample_Time, 'HH') = ROUND(t.Sample_Time, 'HH')"  # Unschärfe bei Betrachtung über Stundengrenze wird billigend in Kauf genommen, damit kartesisches Produkt nur innerhalb einer Stunde entsteht

    # Unbrauchbare Funktion, da Übergänge unsauber werden
    #fuzzy_round_filter = "ROUND(TO_NUMBER(TO_CHAR(t.Sample_Time, 'SSSSS')) / (2*#{@fuzzy_seconds} )) =
    #                      ROUND(TO_NUMBER(TO_CHAR(s.Sample_Time, 'SSSSS')) / (2*#{@fuzzy_seconds} ))"

    #fuzzy_round_filter = "ROUND(s.Sample_Time, 'MI') = ROUND(t.Sample_Time, 'MI')"  if @fuzzy_seconds <= 30
    fuzzy_round_filter = "s.Sample_Time = t.Sample_Time"                            if @fuzzy_seconds == 0        # Direkter Vergleich der Werte wenn keine fuzzy-Funktion gewünscht

    case @time_groupby.to_sym
      when :second then group_by_value = "CAST(s.Sample_Time AS DATE)"
      when :minute then group_by_value = "TRUNC(s.Sample_Time, 'MI')"
      when :hour   then group_by_value = "TRUNC(s.Sample_Time, 'HH24')"
      when :day    then group_by_value = "TRUNC(s.Sample_Time)"
      when :week   then group_by_value = "TRUNC(s.Sample_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end

    # All möglichen Tabellen gejoint, da Filter diese referenzieren können
    @result= sql_select_iterator ["WITH
      #{"procs AS (SELECT /*+ NO_MERGE */ Object_ID, SubProgram_ID, Object_Type, Owner, Object_Name, Procedure_name FROM DBA_Procedures)," if  @global_where_string['peo.'] ||  @global_where_string['po.']}
      #{ash_select(awr_filter: @dba_hist_where_string,
                   sga_filter: @sga_ash_where_string,
                   with_cte_alias: 'ash',
                   dbid: @dbid
      )},
      samples AS (
        SELECT
               CAST (Sample_Time AS DATE) Sample_Time,
               s.Instance_Number, s.Session_ID, s.Session_Serial_No,
               s.Sample_Cycle,                -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
               s.PGA_Allocated,
               s.Temp_Space_Allocated         -- eigentlich nichtssagend, da Summe über alle Sample-Zeiten hinweg, nur benutzt fuer AVG
        FROM   ash s
        #{"LEFT OUTER JOIN DBA_Objects           o   ON o.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Object */ s.P2 ELSE s.Current_Obj_No END" if @global_where_string['o.']}
                                  #{"LEFT OUTER JOIN DBA_Users             u   ON u.User_ID   = s.User_ID" if @global_where_string['u.']}
                                  #{"LEFT OUTER JOIN procs                 peo ON peo.Object_ID = s.PLSQL_Entry_Object_ID AND peo.SubProgram_ID = s.PLSQL_Entry_SubProgram_ID" if @global_where_string['peo.']}
                                  #{"LEFT OUTER JOIN procs                 po  ON po.Object_ID = s.PLSQL_Object_ID        AND po.SubProgram_ID = s.PLSQL_SubProgram_ID" if @global_where_string['po.']}
                                  #{"LEFT OUTER JOIN DBA_Hist_Service_Name sv  ON sv.DBID = s.DBID AND sv.Service_Name_Hash = Service_Hash" if @global_where_string['sv.']}
                                  #{"LEFT OUTER JOIN DBA_Data_Files        f   ON f.File_ID = s.Current_File_No" if @global_where_string['f.']}
        WHERE  1=1
        #{@global_where_string}
      )
      SELECT /*+ ORDERED Panorama-Tool Ramm */
             MIN(s.Sample_Time)   Start_Sample_Time,
             MAX(s.Sample_Time)   End_Sample_Time,
             SUM(Sample_Count)    Sample_Count,
             SUM(Time_Waited_Secs) Time_Waited_Secs,
             MAX(s.Sum_PGA_Allocated)/(1024*1024)                             Max_Sum_PGA_Allocated,
             MAX(s.Sum_PGA_Floating)/(1024*1024 )                             Max_Sum_PGA_Floating,
             MAX(s.Max_PGA_Allocated_per_Session)/(1024*1024)                 Max_PGA_Alloc_Per_Session,
             SUM(s.Sum_PGA_Allocated)/SUM(s.Sample_Count)/(1024*1024)         Avg_PGA_Alloc_per_Session
      FROM   (SELECT Sample_Time,
                     SUM(Sample_Count)      Sample_Count,                       -- Summation über die Sessions des Samples
                     SUM(Time_Waited_Secs)  Time_Waited_Secs,                   -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
                     SUM(PGA_Exact)         Sum_PGA_Allocated,                  -- Summation über die Sessions des Samples
                     SUM(PGA_Floating)      Sum_PGA_Floating,                   -- Summation über die Sessions des Samples
                     MAX(PGA_Exact)         Max_PGA_Allocated_Per_Session       -- Max. Wert einer Session des Samples
              FROM   (SELECT Sample_Time,
                             MAX(Sample_Count)      Sample_Count,
                             MAX(Time_Waited_Secs)  Time_Waited_Secs,
                             MAX(PGA_Exact)         PGA_Exact,
                             MAX(PGA_Floating)      PGA_Floating
                      FROM   (SELECT /*+ NO_MERGE ORDERED */
                                     t.Sample_Time,                   -- Jede vorkommende Sample_Time verknüpft mit Samples vorher und nachher
                                     s.Instance_Number, s.Session_ID, s.Session_Serial_No,  -- Attribute der verknüpften Sessions
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN 1 ELSE 0 END                                                      Sample_Count,
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN ss.Sample_Cycle ELSE 0 END                                        Time_Waited_Secs, -- Gewichtete Zeit in der Annahme, dass Wait aktiv für die Dauer des Samples war (und daher vom Snapshot gesehen wurde)
                                     CASE WHEN t.Sample_Time = s.Sample_Time THEN ss.PGA_Allocated ELSE 0 END                                       PGA_Exact,        -- konkreter Wert zu t.sample_Time
                                     MAX(NVL(ss.PGA_Allocated, 0)) OVER (PARTITION BY s.Instance_Number, s.Session_ID, s.Session_Serial_No, s.Sample_Time)         PGA_Floating     -- Max. Wert je Session zu t.sample_Time +- x Sekunden
                              FROM   (SELECT /*+ NO_MERGE */ DISTINCT Instance_Number, Sample_Time FROM Samples) t
                              JOIN   (SELECT /*+ NO_MERGE */ Sample_Time, Instance_Number, Session_ID, Session_Serial_No FROM Samples) s ON  s.Instance_Number = t.Instance_Number
                                                                                                                                         AND t.Sample_Time >= s.Sample_Time - INTERVAL '#{@fuzzy_seconds}' SECOND AND t.Sample_Time <= s.Sample_Time + INTERVAL '#{@fuzzy_seconds}' SECOND
                                                                                                                                         #{ " AND #{fuzzy_round_filter}" if fuzzy_round_filter}
                              LEFT OUTER JOIN Samples ss ON ss.Sample_Time = t.Sample_Time AND ss.Instance_Number = s.Instance_Number AND ss.Session_ID = s.Session_ID AND ss.Session_Serial_No = s.Session_Serial_No
                             )
                      GROUP BY Sample_Time, Instance_Number, Session_ID, Session_Serial_No  -- Verdichten des mit +/- x Sekunden ausmultiplizierten Ergebnis zurück auf reale Menge
                     )
              GROUP BY Sample_Time     -- Auf Ebene eines Samples reduzieren ueber RAC-Instanzen hinweg
             ) s
      WHERE  s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(@groupfilter[:time_selection_start])}')    -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      AND    s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(@groupfilter[:time_selection_end])}')      -- Nochmal Filtern nach der Rundung auf ganze Sekunden
      GROUP BY #{group_by_value}
      ORDER BY #{group_by_value}
                                  "].concat(@dba_hist_where_values).concat(@sga_ash_where_values).concat(@global_where_values).concat([@groupfilter[:time_selection_start], @groupfilter[:time_selection_end]])


    render_partial :list_pga_usage_historic
  end


end
