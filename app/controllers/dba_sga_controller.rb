# encoding: utf-8
class DbaSgaController < ApplicationController

  #require "dba_helper"   # Erweiterung der Controller um Helper-Methoden
  include DbaHelper

  # Auflösung/Detaillierung der im Feld MODUL geührten Innformation
  def show_application_info
    info =explain_application_info(params[:org_text])
    if info[:short_info]
      explain_text = "#{info[:short_info]}<BR>#{info[:long_info]}"
    else
      explain_text = "nothing known for #{params[:org_text]}"        # Default
    end

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j explain_text }');"}
    end
  end

  def list_sql_area_sql_id  # Auswertung GV$SQLArea
    @modus = "GV$SQLArea"
    list_sql_area(@modus)
  end

  def list_sql_area_sql_id_childno # Auswertung GV$SQL
    @modus = "GV$SQL"
    list_sql_area(@modus)
  end

  private
  def list_sql_area(modus)
    @instance = prepare_param_instance
    @sql_id = params[:sql_id]  =="" ? nil : params[:sql_id].strip
    @filter = params[:filter]  =="" ? nil : params[:filter]
    @sqls = fill_sql_area_list(modus, @instance,
                          @filter,
                          @sql_id,
                          params[:maxResultCount],
                          params[:topSort]
    )

    render_partial :list_sql_area
  end

  def fill_sql_area_list(modus, instance, filter, sql_id, max_result_count, top_sort) # Wird angesprungen aus Vor-Methode
    max_result_count = 100 unless max_result_count
    top_sort         = 'ElapsedTimeTotal' unless top_sort

    where_string = ""
    where_values = []

    if instance
      where_string << " AND s.Inst_ID = ?"
      where_values << instance
    end
    if filter
      where_string << " AND UPPER(SQL_FullText) LIKE UPPER('%'||?||'%')"
      where_values << filter
    end
    if sql_id
      where_string << " AND s.SQL_ID LIKE '%'||?||'%'"
      where_values << sql_id
    end

    where_values << max_result_count

    sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM (SELECT  SUBSTR(LTRIM(SQL_TEXT),1,40) SQL_Text,
                s.SQL_Text Full_SQL_Text,
                s.Inst_ID, s.Parsing_Schema_Name,
                u.USERNAME,
                s.ELAPSED_TIME/1000000 ELAPSED_TIME_SECS,
                (s.ELAPSED_TIME / 1000000) / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) ELAPSED_TIME_SECS_PER_EXECUTE,
                s.DISK_READS,
                s.DISK_READS / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) DISK_READS_PER_EXECUTE,
                s.BUFFER_GETS,
                (s.BUFFER_GETS / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS)) BUFFER_GETS_PER_EXEC,
                s.EXECUTIONS,
                s.PARSE_CALLS, s.SORTS, s.LOADS,
                s.ROWS_PROCESSED,
                s.Rows_Processed / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) Rows_Processed_PER_EXECUTE,
                100 * (s.Buffer_Gets - s.Disk_Reads) / GREATEST(s.Buffer_Gets, 1) Hit_Ratio,
                s.FIRST_LOAD_TIME, s.SHARABLE_MEM, s.PERSISTENT_MEM, s.RUNTIME_MEM,
                ROUND(s.CPU_TIME / 1000000, 3) CPU_TIME_SECS,
                ROUND(s.Cluster_Wait_Time / 1000000, 3) Cluster_Wait_Time_SECS,
                ROUND((s.CPU_TIME / 1000000) / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS), 3) AS CPU_TIME_SECS_PER_EXECUTE,
                s.SQL_ID, s.Plan_Hash_Value, s.Object_Status, s.Last_Active_Time,
                c.Child_Count, c.Plans
                #{modus=="GV$SQL" ? ", s.Child_Number, RAWTOHEX(s.Child_Address) Child_Address" : ", c.Child_Number, c.Child_Address" }
           FROM #{modus} s
           JOIN DBA_USERS u ON u.User_ID = s.Parsing_User_ID
           JOIN (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, COUNT(*) Child_Count, MIN(Child_Number) Child_Number, MIN(RAWTOHEX(Child_Address)) Child_Address,
                        COUNT(DISTINCT Plan_Hash_Value) Plans
                 FROM   GV$SQL GROUP BY Inst_ID, SQL_ID
                ) c ON c.Inst_ID=s.Inst_ID AND c.SQL_ID=s.SQL_ID
          WHERE 1 = 1 -- damit nachfolgende Klauseln mit AND beginnen können
            #{where_string}
            #{" AND Rows_Processed>0" if top_sort == 'BufferGetsPerRow'}
          ORDER BY #{
            case top_sort
              when "ElapsedTimePerExecute"then "s.ELAPSED_TIME/DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) DESC"
              when "ElapsedTimeTotal"     then "s.ELAPSED_TIME DESC"
              when "ExecutionCount"       then "s.Executions DESC"
              when "RowsProcessed"        then "s.Rows_Processed DESC"
              when "ExecsPerDisk"         then "s.Executions/DECODE(s.Disk_Reads,0,1,s.Disk_Reads) DESC"
              when "BufferGetsPerRow"     then "s.Buffer_Gets/DECODE(s.Rows_Processed,0,1,s.Rows_Processed) DESC"
              when "CPUTime"              then "s.CPU_Time DESC"
              when "BufferGets"           then "s.Buffer_gets DESC"
              when "ClusterWaits"         then "s.Cluster_Wait_Time DESC"
              when "LastActive"           then "s.Last_Active_Time DESC"
              when "Memory"               then "s.SHARABLE_MEM+s.PERSISTENT_MEM+s.RUNTIME_MEM DESC"
            end} )
  WHERE ROWNUM < ?
  ORDER BY #{
        case top_sort
          when "ElapsedTimePerExecute"then "ELAPSED_TIME_SECS_PER_EXECUTE DESC"
          when "ElapsedTimeTotal"     then "ELAPSED_TIME_SECS DESC"
          when "ExecutionCount"       then "Executions DESC"
          when "RowsProcessed"        then "Rows_Processed DESC"
          when "ExecsPerDisk"         then "Executions/DECODE(Disk_Reads,0,1,Disk_Reads) DESC"
          when "BufferGetsPerRow"     then "Buffer_Gets/DECODE(Rows_Processed,0,1,Rows_Processed) DESC"
          when "CPUTime"              then "CPU_Time_Secs DESC"
          when "BufferGets"           then "Buffer_gets DESC"
          when "ClusterWaits"         then "Cluster_Wait_Time_Secs DESC"
          when "LastActive"           then "Last_Active_Time DESC"
          when "Memory"               then "SHARABLE_MEM+PERSISTENT_MEM+RUNTIME_MEM DESC"
        end}"
    ].concat(where_values)
  end

  private
  # Modus enthält GV$SQL oder GV$SQLArea
  def fill_sql_sga_stat(modus, instance, sql_id, object_status, child_number=nil, parsing_schema_name=nil, child_address=nil)
    where_string = ""
    where_values = []

    if instance
      where_string << " AND s.Inst_ID = ?"
      where_values << instance
    end

    if object_status
      where_string << " AND s.Object_Status = ?"
      where_values << object_status
    end

    if modus == "GV$SQL"
      where_string << " AND s.Child_Number = ?"
      where_values << child_number

      unless child_address.nil?
        where_string << " AND s.Child_Address = HEXTORAW(?)"
        where_values << child_address
      end
    end

    if parsing_schema_name
      where_string << " AND s.Parsing_Schema_Name = ?"
      where_values << parsing_schema_name
    end

    sql = sql_select_first_row ["\
      SELECT /* Panorama-Tool Ramm */
                s.ELAPSED_TIME/1000000 ELAPSED_TIME_SECS,
                s.Inst_ID, s.Object_Status,
                s.DISK_READS,
                s.BUFFER_GETS,
                s.EXECUTIONS, Fetches,
                s.PARSE_CALLS, s.SORTS, s.LOADS, s.ROWS_PROCESSED,
                100 * (s.Buffer_Gets - s.Disk_Reads) / GREATEST(s.Buffer_Gets, 1) Hit_Ratio,
                s.FIRST_LOAD_TIME, s.Last_Load_Time, s.SHARABLE_MEM, s.PERSISTENT_MEM, s.RUNTIME_MEM,
                s.Last_Active_Time,
                s.CPU_TIME/1000000 CPU_TIME_SECS,
                s.Application_Wait_Time/1000000 Application_Wait_Time_secs,
                s.Concurrency_Wait_Time/1000000 Concurrency_Wait_Time_secs,
                s.Cluster_Wait_Time/1000000     Cluster_Wait_Time_secs,
                s.User_IO_Wait_Time/1000000     User_IO_Wait_Time_secs,
                s.PLSQL_Exec_Time/1000000       PLSQL_Exec_Time_secs,
                s.SQL_ID,
                #{modus=="GV$SQL" ? "Child_Number, RAWTOHEX(Child_Address) Child_Address, " : "" }
                (SELECT COUNT(*) FROM GV$SQL c WHERE c.Inst_ID = s.Inst_ID AND c.SQL_ID = s.SQL_ID) Child_Count,
                #{modus=="GV$SQL" ? "1" : "(SELECT COUNT(DISTINCT Plan_Hash_Value) FROM GV$SQL c WHERE c.Inst_ID = s.Inst_ID AND c.SQL_ID = s.SQL_ID)" } Plan_Hash_Value_Count,
                s.Plan_Hash_Value, /* Enthaelt im Falle v$SQLArea nur einem von mehreren moeglichen Werten */
                s.Optimizer_Env_Hash_Value, s.Module, s.Action, s.Inst_ID,
                s.Parsing_Schema_Name, SQL_Profile,
                o.Owner||'.'||o.Object_Name Program_Name, o.Object_Type Program_Type, o.Last_DDL_Time Program_Last_DDL_Time,
                s.Program_Line# Program_LineNo, #{'SQL_Plan_Baseline, ' if get_db_version >= '11.2'}
                DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_FullText, 0) Exact_Signature,
                DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_FullText, 1) Force_Signature
           FROM #{modus} s
           LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = s.Program_ID -- PL/SQL-Programm
           WHERE s.SQL_ID  = ? #{where_string}
           ", sql_id].concat where_values
    if sql.nil? && object_status
      sql = fill_sql_sga_stat(modus, instance, sql_id, nil, child_number, parsing_schema_name)
      sql[:warning_message] = "No SQL found with Object_Status='#{object_status}' in #{modus}. Filter Object_Status is supressed now." if sql
    end
    if sql.nil? && parsing_schema_name
      sql = fill_sql_sga_stat(modus, instance, sql_id, object_status, child_number, nil)
      sql[:warning_message] = "No SQL found with Parsing_Schema_Name='#{parsing_schema_name}' in #{modus}. Filter Parsing_Schema_Name is supressed now." if sql
    end

    sql
  end

  private
  def get_open_cursor_count(instance, sql_id)
    sql_select_one ["\
        SELECT /* Panorama-Tool Ramm */ COUNT(*)
        FROM   gv$Open_Cursor o
        WHERE  o.Inst_ID = ?
        AND    o.SQL_ID  = ?",
        instance, sql_id]
  end

  def sql_monitor_session_count(instance, sql_id, plan_hash_value = nil)
    if get_db_version >= "11.1"
      where_string = ''
      where_values = []

      if instance
        where_string << " AND Inst_ID = ?"
        where_values << instance
      end

      if plan_hash_value
        where_string << " AND SQL_Plan_Hash_Value = ?"
        where_values << plan_hash_value
      end

      sql_select_one ["SELECT /* Panorama-Tool Ramm */ COUNT(*)
                       FROM   (SELECT SQL_ID, SQL_Exec_ID, SQL_Exec_Start
                               FROM   gv$SQL_Monitor
                               WHERE  SQL_ID = ? #{where_string}
                               GROUP BY SQL_ID, SQL_Exec_ID, SQL_Exec_Start
                               HAVING SUM(DECODE(Process_Name, 'ora', 1, 0)) > 0 /* mindestens ein Record muss Process_Name = ora haben */

                              )
                      ", sql_id].concat(where_values)
    else
      0
    end
  end

  # Existierende SQL-Profiles, Parameter: Result-Zeile eines selects
  def get_sql_profiles(sql_row)
    sql_select_all ["SELECT * FROM DBA_SQL_Profiles WHERE Signature = TO_NUMBER(?) OR  Signature = TO_NUMBER(?) #{'OR Name = ?' if sql_row.sql_profile}
                    ",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s].concat(sql_row.sql_profile ? [sql_row.sql_profile] : []) if sql_row
  end

  # Existierende SQL-Plan Baselines, Parameter: Result-Zeile eines selects
  def get_sql_plan_baselines(sql_row)
    if get_db_version >= "11.2"
      sql_select_all ["SELECT * FROM DBA_SQL_Plan_Baselines WHERE Signature = TO_NUMBER(?) OR  Signature = TO_NUMBER(?) #{'OR Plan_Name = ?' if sql_row.sql_plan_baseline}
                      ",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s].concat(sql_row.sql_plan_baseline ? [sql_row.sql_plan_baseline] : []) if sql_row
    else
      []
    end
  end

  # Existierende stored outlines, Parameter: Result-Zeile eines selects
  def get_sql_outlines(sql_row)
    sql_select_all ["SELECT * FROM DBA_Outlines WHERE Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?)) OR  Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?))",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s] if sql_row
  end

  public

  def list_sql_profile_detail
    @profile_name = params[:profile_name]

    @details = sql_select_all ["\
                SELECT Comp_Data
                FROM   DBMSHSXP_SQL_PROFILE_ATTR
                WHERE  Profile_Name = ?", @profile_name]
    render_partial
  end

  # Erzeugt Daten für execution plan
  def get_sga_execution_plan(modus, sql_id, instance, child_number, child_address, restrict_ash_to_child)
    where_string = ''
    where_values = []

    unless child_address.nil?
      where_string << 'AND Child_Address = HEXTORAW(?)'
      where_values << child_address
    end

    plans = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Operation, Options, Object_Owner, Object_Name, Object_Type, Object_Alias, QBlock_Name, p.Timestamp,
          CASE WHEN p.ID = 0 THEN (SELECT Optimizer    -- Separater Zugriff auf V$SQL_Plan, da nur dort die Spalte Optimizer gefüllt ist
                                    FROM  gV$SQL_Plan sp
                                    WHERE sp.SQL_ID          = p.SQL_ID
                                    AND   sp.Inst_ID         = p.Inst_ID
                                    AND   sp.Child_Number    = p.Child_Number
                                    AND   sp.Child_Address   = p.Child_Address
                                    AND   sp.Plan_Hash_Value = p.Plan_Hash_Value
                                    AND   sp.ID              = 0
                                   ) ELSE NULL END Optimizer,
          DECODE(Other_Tag,
                 'PARALLEL_COMBINED_WITH_PARENT', 'PCWP',
                 'PARALLEL_COMBINED_WITH_CHILD' , 'PCWC',
                 'PARALLEL_FROM_SERIAL',          'S > P',
                 'PARALLEL_TO_PARALLEL',          'P > P',
                 'PARALLEL_TO_SERIAL',            'P > S',
                 Other_Tag
                ) Parallel_Short,
          Other_Tag, Other_XML,
          Depth, Access_Predicates, Filter_Predicates, Projection, p.temp_Space/(1024*1024) Temp_Space_MB, Distribution,
          ID, Parent_ID, Executions, p.Search_Columns,
          Last_Starts, Starts, Last_Output_Rows, Output_Rows, Last_CR_Buffer_Gets, CR_Buffer_Gets,
          Last_CU_Buffer_Gets, CU_Buffer_Gets, Last_Disk_Reads, Disk_Reads, Last_Disk_Writes, Disk_Writes,
          Last_Elapsed_Time/1000 Last_Elapsed_Time, Elapsed_Time/1000 Elapsed_Time,
          p.Cost, p.Cardinality, p.CPU_Cost, p.IO_Cost, p.Bytes, p.Partition_Start, p.Partition_Stop, p.Partition_ID, p.Time,
          NVL(t.Num_Rows, i.Num_Rows) Num_Rows,
          NVL(t.Last_Analyzed, i.Last_Analyzed) Last_Analyzed,
          (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner=p.Object_Owner AND s.Segment_Name=p.Object_Name) MBytes
          #{", a.DB_Time_Seconds, a.CPU_Seconds, a.Waiting_Seconds, a.Read_IO_Requests, a.Write_IO_Requests,
               a.IO_Requests, a.Read_IO_Bytes, a.Write_IO_Bytes, a.Interconnect_IO_Bytes, a.Min_Sample_Time, a.Max_Sample_Time, a.Max_Temp_ASH_MB, a.Max_PGA_ASH_MB, a.Max_PQ_Sessions " if get_db_version >= "11.2"}
        FROM  gV$SQL_Plan_Statistics_All p
        LEFT OUTER JOIN DBA_Tables  t ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name
        LEFT OUTER JOIN DBA_Indexes i ON i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name
        #{" LEFT OUTER JOIN (SELECT SQL_PLan_Line_ID, SQL_Plan_Hash_Value,
                                    SUM(DB_Time_Seconds)                    DB_Time_Seconds,
                                    SUM(CPU_Seconds)                        CPU_Seconds,
                                    SUM(Waiting_Seconds)                    Waiting_Seconds,
                                    SUM(Read_IO_Requests)                   Read_IO_Requests,
                                    SUM(Write_IO_Requests)                  Write_IO_Requests,
                                    SUM(IO_Requests)                        IO_Requests,
                                    SUM(Read_IO_Bytes)                      Read_IO_Bytes,
                                    SUM(Write_IO_Bytes)                     Write_IO_Bytes,
                                    SUM(Interconnect_IO_Bytes)              Interconnect_IO_Bytes,
                                    MIN(Min_Sample_Time)                    Min_Sample_Time,
                                    MAX(Max_Sample_Time)                    Max_Sample_Time,
                                    MAX(Temp)/(1024*1024)                   Max_Temp_ASH_MB,
                                    MAX(PGA)/(1024*1024)                    Max_PGA_ASH_MB,
                                    MAX(PQ_Sessions)                        Max_PQ_Sessions     -- max. Anzahl PQ-Slaves + Koordinator für eine konkrete Koordinator-Session
                             FROM   (
                                     SELECT SQL_PLan_Line_ID, SQL_Plan_Hash_Value,
                                            COUNT(*)                                                   DB_Time_Seconds,
                                            SUM(CASE WHEN Session_State = 'ON CPU'  THEN 1 ELSE 0 END) CPU_Seconds,
                                            SUM(CASE WHEN Session_State = 'WAITING' THEN 1 ELSE 0 END) Waiting_Seconds,
                                            SUM(Delta_Read_IO_Requests)       Read_IO_Requests,
                                            SUM(Delta_Write_IO_Requests)      Write_IO_Requests,
                                            SUM(NVL(Delta_Read_IO_Requests,0)+NVL(Delta_Write_IO_Requests,0)) IO_Requests,
                                            SUM(Delta_Read_IO_Bytes)          Read_IO_Bytes,
                                            SUM(Delta_Write_IO_Bytes)         Write_IO_Bytes,
                                            SUM(Delta_Interconnect_IO_Bytes)  Interconnect_IO_Bytes,
                                            MIN(Sample_Time)                  Min_Sample_Time,
                                            MAX(Sample_Time)                  Max_Sample_Time,
                                            SUM(Temp_Space_Allocated)         Temp,
                                            SUM(PGA_Allocated)                PGA,
                                            COUNT(DISTINCT CASE WHEN QC_Session_ID IS NULL OR QC_Session_ID = Session_ID THEN NULL ELSE Session_ID END) PQ_Sessions   -- Anzahl unterschiedliche PQ-Slaves + Koordinator für diese Koordiantor-Session
                                     FROM   gv$Active_Session_History
                                     WHERE  SQL_ID  = ?
                                     AND    Inst_ID = ?
                                     #{(modus == 'GV$SQL' && restrict_ash_to_child ) ? 'AND    SQL_Child_Number = ?' : ''}   -- auch andere Child-Cursoren von PQ beruecksichtigen wenn Child-uebergreifend angefragt
                                     GROUP BY SQL_Plan_Line_ID, SQL_Plan_Hash_Value, NVL(QC_Session_ID, Session_ID), Sample_ID   -- Alle PQ-Werte mit auf Session kumulieren
                                    )
                             GROUP BY SQL_Plan_Line_ID, SQL_Plan_Hash_Value
                 ) a ON a.SQL_Plan_Line_ID = p.ID AND a.SQL_Plan_Hash_Value = p.Plan_Hash_Value
          " if get_db_version >= "11.2"}
        WHERE SQL_ID  = ?
        AND   Inst_ID = ?
        AND   Child_Number = ?
        #{where_string}
        ORDER BY ID"
        ].concat(get_db_version >= "11.2" ? [sql_id, instance].concat(modus == 'GV$SQL' ? [child_number] : []) : []).concat([sql_id, instance, child_number]).concat(where_values)

    # Vergabe der exec-Order im Explain
    # iteratives neu durchsuchen der Liste nach folgenden erfuellten Kriterien
    # - ID tritt nicht als Parent auf
    # - alle Children als Parent sind bereits mit ExecOrder versehen
    # gefundene Records werden mit aufteigender Folge versehen und im folgenden nicht mehr betrachtet

    # Array mit den Positionen der Objekte in plans anlegen
    pos_array = []
    0.upto(plans.length-1) {|i|  pos_array << i }

    plans.each do |p|
      p[:is_parent] = false                                                     # Vorbelegung
    end

    curr_execorder = 1                                             # Startwert
    while pos_array.length > 0                                     # Bis alle Records im PosArray mit Folge versehen sind
      pos_array.each {|i|                                          # Iteration ueber Verbliebene Records
        is_parent = false                                          # Default-Annahme, wenn kein Child gefunden
        pos_array.each {|x|                                        # Suchen, ob noch ein Child zum Parent existiert in verbliebener Menge
          if plans[i].id == plans[x].parent_id                     # Doch noch ein Child zum Parent gefunden
            is_parent = true
            plans[i][:is_parent] = true                            # Merken Status als Knoten
            break                                                  # Braucht nicht weiter gesucht werden
          end
        }
        unless is_parent
          plans[i].execorder = curr_execorder                      # Vergabe Folge
          curr_execorder = curr_execorder + 1
          pos_array.delete(i)                                      # entwerten der verarbeiten Zeile fuer Folgebetrachtung
          break                                                    # Neue Suche vom Beginn an
        end
      }
    end
    plans
  end


  # Anzeige Einzeldetails des SQL
  def list_sql_detail_sql_id_childno
    @modus = "GV$SQL"   # Detaillierung SQL-ID, ChildNo
    @instance     = prepare_param_instance
    @sql_id       = params[:sql_id]
    @child_number = params[:child_number].to_i
    @child_address = params[:child_address]
    @object_status= params[:object_status]
    @object_status='VALID' unless @object_status  # wenn kein status als Parameter uebergeben, dann VALID voraussetzen
    @parsing_schema_name = params[:parsing_schema_name]

    @sql                 = fill_sql_sga_stat("GV$SQL", @instance, @sql_id, @object_status, @child_number, @parsing_schema_name, @child_address)
    @sql_statement       = get_sga_sql_statement(@instance, @sql_id)
    @sql_profiles        = get_sql_profiles(@sql)
    @sql_plan_baselines  = get_sql_plan_baselines(@sql)
    @sql_outlines        = get_sql_outlines(@sql)

    @plans               = get_sga_execution_plan(@modus, @sql_id, @instance, @child_number, @child_address, true)

    # PGA-Workarea-Nutzung
    @workareas = sql_select_all ["\
      SELECT /* Panorama Ramm */ w.*,
             s.Serial# SerialNo,
             sq.Serial# QCSerialNo
      FROM   gv$SQL_Workarea_Active w
      JOIN   gv$Session s ON s.Inst_ID=w.Inst_ID AND s.SID=w.SID
      LEFT OUTER JOIN gv$Session sq ON sq.Inst_ID=w.QCInst_ID AND sq.SID=w.QCSID
      WHERE  w.SQL_ID = ?
      ORDER BY w.QCSID, w.SID
      ",  @sql_id]

    # Bindevariablen des Cursors
    @binds = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Name, Position, DataType_String, Last_Captured,
             CASE DataType_String
               WHEN 'TIMESTAMP' THEN TO_CHAR(ANYDATA.AccessTimestamp(Value_AnyData), '#{sql_datetime_minute_mask}')
             ELSE Value_String END Value_String,
             Child_Number,
             NLS_CHARSET_NAME(Character_SID) Character_Set, Precision, Scale, Max_Length
      FROM   gv$SQL_Bind_Capture c
      WHERE  Inst_ID = ?
      AND    SQL_ID  = ?
      AND    Child_Number = ?
      #{" AND Child_Address = HEXTORAW(?)" unless @child_address.nil?}
      ORDER BY Position
      ", @instance, @sql_id, @child_number ].concat(@child_address.nil? ? [] : [@child_address])

    @open_cursors         = get_open_cursor_count(@instance, @sql_id)
    @sql_monitor_sessions = sql_monitor_session_count(@instance, @sql_id, @sql.plan_hash_value)

    if @sql
      render_partial :list_sql_detail_sql_id_childno
    else
      show_popup_message("#{t(:dba_sga_list_sql_detail_sql_id_childno_no_hit_msg, :default=>'No record found in GV$SQL for')} SQL_ID='#{@sql_id}', Instance=#{@instance}, Child_Number=#{@child_number}")
    end
  end

  # Details auf Ebene SQL_ID kumuliert über Child-Cursoren
  def list_sql_detail_sql_id
    @instance = prepare_param_instance
    @sql_id   = params[:sql_id]
    @object_status= params[:object_status]
    @object_status='VALID' unless @object_status  # wenn kein status als Parameter uebergeben, dann VALID voraussetzen

    # Liste der Child-Cursoren
    @sqls = fill_sql_area_list("GV$SQL", @instance, nil, @sql_id, 100, nil)

    if @sqls.count == 0
      respond_to do |format|
        format.js { render :js => "alert(\"SQL-ID '#{@sql_id}' not found in GV$SQL for instance = #{@instance} !\");" }
      end
      return
    end


      # Test auf unterschiedliche Instances in Treffern,  Hash[@sqls.map{|s| [s.int_id, 1]}].count sollte dies auch tun
    instances = {}
    @sqls.each do |s|
      instances[s.inst_id] = 1
    end
    if instances.count > 1
      list_sql_area_sql_id                                                      # Auswahl der konkreten Instance aus Liste auslösen
      return
    end

    @instance = @sqls[0].inst_id                                                # ab hier kann es nur Records einer Instance geben

    if @sqls.count == 1     # Nur einen Child-Cursor gefunden, dann direkt weiterleiten an Anzeige auf Child-Ebene
      @list_sql_sga_stat_msg = "Nur ein Child-Record gefunden in gv$SQL, daher gleich direkte Anzeige auf Child-Ebene"
      params[:instance]     = @instance
      params[:child_number] = @sqls[0].child_number
      list_sql_detail_sql_id_childno  # Anzeige der Child-Info
      return
    end

    @sql = fill_sql_sga_stat("GV$SQLArea", @instance, params[:sql_id], @object_status)
    @sql_statement         = get_sga_sql_statement(@instance, params[:sql_id])
    @sql_profiles          = get_sql_profiles(@sql)
    @sql_plan_baselines    = get_sql_plan_baselines(@sql)
    @sql_outlines          = get_sql_outlines(@sql)
    @open_cursors          = get_open_cursor_count(@instance, @sql_id)
    @sql_monitor_sessions  = sql_monitor_session_count(@instance, @sql_id)

    sql_child_info = sql_select_first_row ["SELECT COUNT(DISTINCT plan_hash_value) Plan_Count,
                                                   MIN(Child_Number)          Min_Child_Number,
                                                   MIN(RAWTOHEX(Child_Address)) KEEP (DENSE_RANK FIRST ORDER BY Child_Number)   Min_Child_Address
                                            FROM   gv$SQL
                                            WHERE  Inst_ID = ? AND SQL_ID = ?", @instance, @sql_id]

    @plans = get_sga_execution_plan('GV$SQLArea', @sql_id, @instance, sql_child_info.min_child_number, sql_child_info.min_child_address, false) if sql_child_info.plan_count == 1 # Nur anzeigen wenn eindeutig immer der selbe plan

    render_partial :list_sql_detail_sql_id

  end

  def list_sql_shared_cursor
    @instance     = params[:instance]
    @sql_id       = params[:sql_id]

    # Dyn. Erstellen SQL aus Spalten-Info des Views gv$SQL_Shared_Cursor, um nicht alle Spalten kennen zu müssen

    @reasons = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ * FROM gv$SQL_Shared_Cursor WHERE Inst_ID=? AND SQL_ID=?",
      @instance, @sql_id, @child_number]

    @reasons.each do |r|
      reasons = ""        # Konkatenierte Strings mit Gründen
      r.each do |key, value|
        if key!="inst_id" && key!="sql_id" && key!="address" && key!="child_address" && key!="child_number" && key!="reason"
          reasons << "#{key}, "if value == 'Y'
        end
      end
      r["reasons"] = reasons   # Spalte im Result hinzufügen
    end

    render_partial
  end

  # Anzeige der offenen Cursor eines SQL
  def list_open_cursor_per_sql
    @instance     = prepare_param_instance
    @sql_id       = params[:sql_id]

    @open_cursors = sql_select_all ["\
       SELECT /* Panorama-Tool Ramm */
              s.SID,
              s.Inst_ID,
              s.Serial# SerialNo,
              s.UserName,
              s.OSUser,
              s.Process,
              s.Machine,
              s.Program,
              s.Module,
              DECODE(o.SQL_ID, s.SQL_ID, 'Y', 'N') Stmt_Active
       FROM   gv$Open_Cursor o,
              gv$Session s
       WHERE  s.Inst_ID = o.Inst_ID
       AND    s.SAddr   = o.SAddr
       AND    s.SID     = o.SID
       AND    o.Inst_ID = ?
       AND    o.SQL_ID  = ?
       ", @instance, @sql_id]

    render_partial
  end

  # SGA-Komponenten 
  def list_sga_components
    @instance        = prepare_param_instance
    @sums = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             Inst_ID, NVL(Pool, Name) Pool, sum(Bytes) Bytes, NULL Parameter
      FROM   gv$sgastat
      #{@instance ? "WHERE  Inst_ID = ?" : ""}
      GROUP BY Inst_ID, NVL(Pool, Name)
      ORDER BY 3 DESC", @instance]

    @sums.each do |s|
      s['parameter'] =
          case s.pool
            when 'buffer_cache' then "db_block_buffers = #{ sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'db_block_buffers'])}, db_cache_size = #{sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'db_cache_size'])}"
            when 'java pool'    then "java_pool_size = #{   sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'java_pool_size'])}"
            when 'large pool'   then "large_pool_size = #{  sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'large_pool_size'])}"
            when 'log_buffer'   then "log_buffer = #{       sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'log_buffer'])}"
            when 'shared pool'  then "shared_pool_size = #{ sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'shared_pool_size'])}"
            when 'streams pool' then "streams_pool_size = #{sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'streams_pool_size'])}"
          end

    end

    @components = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
        Inst_ID,
        Pool,                                                   
        Name,                                                   
        Bytes
      FROM GV$SGAStat
      #{@instance ? "WHERE  Inst_ID = ?" : ""}
      ORDER BY Bytes DESC", @instance]

    @objects = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
        Inst_ID, Type, Namespace, DB_Link, Kept,
        SUM(Sharable_Mem)/(1024*1024)   Sharable_Mem_MB,
        SUM(Loads)                      Loads,
        SUM(Locks)                      Locks,
        SUM(Pins)                       Pins,
        SUM(Invalidations)              Invalidations,
        COUNT(*)                        Counts,
        COUNT(DISTINCT Owner||'.'||Name) Count_Distinct
      FROM GV$DB_Object_Cache
      #{@instance ? "WHERE  Inst_ID = ?" : ""}
      GROUP BY Inst_ID, Type, Namespace, DB_Link, Kept
      ORDER BY 6 DESC", @instance]


    render_partial
  end

  def list_db_cache_content
    @instance        = prepare_param_instance
    raise "Instance muss belegt sein" unless @instance
    @show_partitions = params[:show_partitions]
    @sysdate = (sql_select_all "SELECT SYSDATE FROM DUAL")[0].sysdate
    @db_cache_global_sums = sql_select_all ["
      SELECT /* Panorama-Tool Ramm */
             x.Status, SUM(Blocks) Blocks,
             SUM(x.Blocks * ts.BlockSize)/(1024*1024) MB_Total
      FROM   (SELECT Inst_ID, Status, TS#, Count(*) Blocks
              FROM GV$BH
              WHERE Inst_ID=?
              GROUP BY Inst_ID, Status, TS#
             ) x
      LEFT OUTER JOIN   sys.TS$ ts ON ts.TS# = x.TS#
      GROUP BY x.Inst_ID, x.Status
      ", @instance];

    @total_status_blocks = 0                  # Summation der Blockanzahl des Caches
    @db_cache_global_sums.each do |c|
      @total_status_blocks += c.blocks
    end


    # Konkrete Objekte im Cache
    @objects = sql_select_all ["
      SELECT /*+ RULE */ /* Panorama-Tool Ramm */
        NVL(o.Owner,'[UNKNOWN]') Owner,                       
        NVL(o.Object_Name,'TS='||ts.Name) Object_Name,
        #{@show_partitions=="1" ? "o.SubObject_Name" : "''"} SubObject_Name,
        MIN(o.Object_Type) Object_Type,  -- MIN statt Aufnahme in GROUP BY
        MIN(CASE WHEN o.Object_Type LIKE 'INDEX%' THEN
                  (SELECT Table_Name FROM DBA_Indexes i WHERE i.Owner = o.Owner AND i.Index_Name = o.Object_Name)
        ELSE NULL END) Table_Name, -- MIN statt Aufnahme in GROUP BY
        SUM(bh.Blocks * ts.BlockSize) / (1024*1024) Size_MB,
        SUM(bh.Blocks)      Blocks,
        SUM(bh.DirtyBlocks) DirtyBlocks,
        SUM(bh.TempBlocks)  TempBlocks,
        SUM(bh.Ping)        Ping,
        SUM(bh.Stale)       Stale,
        SUM(bh.Direct)      Direct,
        SUM(Forced_Reads)   Forced_Reads,
        SUM(Forced_Writes)  Forced_Writes,
        SUM(Status_cr)      Status_cr,
        SUM(Status_pi)      Status_pi,
        SUM(Status_read)    Status_read,
        SUM(Status_scur)    Status_scur,
        SUM(Status_xcur)    Status_xcur
      FROM                                                    
        (SELECT /*+ NO_MERGE */
                ObjD, TS#,
                Count(*) Blocks,
                SUM(DECODE(Dirty,'Y',1,0))  DirtyBlocks,
                SUM(DECODE(Temp,'Y',1,0))   TempBlocks,
                SUM(DECODE(Ping,'Y',1,0))   Ping,
                SUM(DECODE(Stale,'Y',1,0))  Stale,
                SUM(DECODE(Direct,'Y',1,0)) Direct,
                SUM(Forced_Reads)           Forced_Reads,
                SUM(Forced_Writes)          Forced_Writes,
                SUM(DECODE(Status, 'cr', 1, 0))    Status_cr,
                SUM(DECODE(Status, 'pi', 1, 0))    Status_pi,
                SUM(DECODE(Status, 'read', 1, 0))    Status_read,
                SUM(DECODE(Status, 'scur', 1, 0))    Status_scur,
                SUM(DECODE(Status, 'xcur', 1, 0))    Status_xcur
        FROM GV$BH                                            
        WHERE Status != 'free'  /* dont show blocks of truncated tables */
        AND   Inst_ID = ?
        GROUP BY ObjD, TS#
        ) BH
        LEFT OUTER JOIN DBA_Objects o ON o.Data_Object_ID = bh.ObjD
        LEFT OUTER JOIN sys.TS$ ts ON ts.TS# = bh.TS#
      GROUP BY NVL(o.Owner,'[UNKNOWN]'), NVL(o.Object_Name,'TS='||ts.Name)#{@show_partitions=="1" ? ", o.SubObject_Name" : ""}
      ORDER BY 6 DESC", @instance];
    @total_blocks = 0                  # Summation der Blockanzahl des Caches
    @objects.each do |o|
      @total_blocks += o.blocks
    end

    render_partial
  end # list_db_cache_content

  def show_using_sqls
    @object_owner = params[:ObjectOwner]
    @object_owner = nil if @object_owner == ""
    @object_name = params[:ObjectName]
    @instance = prepare_param_instance

    wherestr = "p.Object_Name LIKE UPPER(?)"
    whereval = [@object_name]

    if @object_owner
      wherestr << " AND p.Object_Owner=UPPER(?)"
      whereval << @object_owner
    end

    if @instance
      wherestr << " AND p.Inst_ID=?"
      whereval << @instance
    end

    @sqls = sql_select_iterator ["
       SELECT s.Inst_ID, SUBSTR(s.SQL_TEXT,1,100) SQL_Text,
              s.Executions, s.Fetches, s.First_load_time,       
              s.Parsing_Schema_Name,
              s.last_load_time,
              s.ELAPSED_TIME/1000000 ELAPSED_TIME_SECS,
              (s.ELAPSED_TIME/1000000) / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) ELAPSED_TIME_SECS_PER_EXECUTE,
              ROUND(s.CPU_TIME / 1000000, 3) CPU_TIME_SECS,
              s.DISK_READS,
              s.DISK_READS / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) DISK_READS_PER_EXECUTE,
              s.BUFFER_GETS,
              s.BUFFER_GETS / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) BUFFER_GETS_PER_EXEC,
              s.ROWS_PROCESSED,
              s.Rows_Processed / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS) Rows_Processed_PER_EXECUTE,
              s.SQL_ID, s.Child_Number,
              p.operation, p.options, p.access_predicates, p.Search_Columns, p.Filter_Predicates
       FROM gV$SQL_Plan p
       JOIN gv$SQL s     ON (    s.SQL_ID          = p.SQL_ID
                             AND s.Plan_Hash_Value = p.Plan_Hash_Value
                             AND s.Inst_ID         = p.Inst_ID
                             AND s.Child_Number    = p.Child_Number
                            )
       WHERE #{wherestr}
       ORDER BY s.Elapsed_Time DESC"].concat whereval;
    render_partial
  end

  def list_cursor_memory
    @instance =  prepare_param_instance
    @sid      =  params[:sid].to_i
    @serialno = params[:serialno].to_i
    @sql_id   = params[:sql_id]

        @workareas = sql_select_all ["
      SELECT /*+ ORDERED USE_HASH(s wa) */
             *
      FROM   gv$SQL_Workarea wa
      WHERE  wa.Inst_ID=? AND wa.SQL_ID=?
      ", @instance, @sql_id]

    render_partial
  end


  def list_compare_execution_plans
    @instance_1 = params[:instance_1].to_i
    @instance_2 = params[:instance_2].to_i
    @sql_id_1 = params[:sql_id_1]
    @sql_id_2 = params[:sql_id_2]
    @child_number_1 = params[:child_number_1].to_i
    @child_number_2 = params[:child_number_2].to_i

    @plan_count = sql_select_one ["\
            SELECT /* Panorama-Tool Ramm */ COUNT(DISTINCT Plan_Hash_Value)
            FROM  gV$SQL_Plan p
            WHERE (    Inst_ID      = ?
                   AND SQL_ID       = ?
                   AND Child_Number = ?
                  )
            OR    (    Inst_ID      = ?
                   AND SQL_ID       = ?
                   AND Child_Number = ?
                  )
            ",
            @instance_1, @sql_id_1, @child_number_1, @instance_2, @sql_id_2, @child_number_2
            ]

    plans = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Inst_ID, SQL_ID, Child_Number,
          Operation, Options, Object_Owner, Object_Name, Object_Type, Optimizer,
          DECODE(Other_Tag,
                 'PARALLEL_COMBINED_WITH_PARENT', 'PCWP',
                 'PARALLEL_COMBINED_WITH_CHILD' , 'PCWC',
                 'PARALLEL_FROM_SERIAL',          'S > P',
                 'PARALLEL_TO_PARALLEL',          'P > P',
                 'PARALLEL_TO_SERIAL',            'P > S',
                 Other_Tag
                ) Parallel_Short,
          Other_Tag Parallel,
          Depth, Access_Predicates, Filter_Predicates, temp_Space, Distribution,
          ID, Parent_ID,
          Count(*) OVER (PARTITION BY p.Parent_ID, p.Operation, p.Options, p.Object_Owner,    -- p.ID nicht abgleichen, damit Verschiebungen im Plan toleriert werden
                        CASE WHEN p.Object_Name LIKE ':TQ%'
                          THEN 'Hugo'
                          ELSE p.Object_Name END,
                        p.Other_Tag, p.Depth,
                        p.Access_Predicates, p.Filter_Predicates, p.Distribution
          ) Version_Orange_Count,
          Count(*) OVER (PARTITION BY p.Parent_ID, p.Operation, p.Options, p.Object_Owner,     -- p.ID nicht abgleichen, damit Verschiebungen im Plan toleriert werden
                        CASE WHEN p.Object_Name LIKE ':TQ%'
                          THEN 'Hugo'
                          ELSE p.Object_Name END,
                       p.Depth
          ) Version_Red_Count
        FROM  gV$SQL_Plan p
        WHERE (    Inst_ID      = ?
               AND SQL_ID       = ?
               AND Child_Number = ?
              )
        OR    (    Inst_ID      = ?
               AND SQL_ID       = ?
               AND Child_Number = ?
              )
        ORDER BY ID",
        @instance_1, @sql_id_1, @child_number_1, @instance_2, @sql_id_2, @child_number_2
        ]

    @plan_1, @plan_2 = [], []
    plans.each do |p|
      @plan_1 << p if p.inst_id == @instance_1 && p.sql_id == @sql_id_1 && p.child_number == @child_number_1
      @plan_2 << p if p.inst_id == @instance_2 && p.sql_id == @sql_id_2 && p.child_number == @child_number_2
    end

    render_partial
  end

  # Result Cache
  def list_result_cache
    if get_db_version < "11.1"
      respond_to do |format|
        format.js {render :js => "$('##{params[:update_area]}').html('<h2>This funktion is available only for Oracle 11g and above</h2>');"}
      end
      return
    end


    @instance        = prepare_param_instance

    @sums = sql_select_all ["\
          SELECT /* Panorama-Tool Ramm */
                 s.Inst_ID, s.Space_Bytes, ms.Value Max_Size
          FROM   (SELECT
                         o.Inst_ID, SUM(Space_Overhead) + SUM(Space_Unused) Space_Bytes
                  FROM   gv$Result_Cache_Objects o
                  WHERE  Type = 'Result'
                  #{@instance ? " AND Inst_ID = ?" : ""}
                  GROUP BY Inst_ID
                 ) s
          JOIN   gv$Parameter ms ON ms.Inst_ID = s.Inst_ID AND ms.Name = 'result_cache_max_size'
          ", @instance]

    @usage = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             (SELECT UserName FROM DBA_Users WHERE User_ID = o.Min_User_ID) Min_Creator,
             (SELECT UserName FROM DBA_Users WHERE User_ID = o.Max_User_ID) Max_Creator,
             CASE WHEN Creator_Count > 1 THEN '< '||Creator_Count||' >' ELSE (SELECT UserName FROM DBA_Users WHERE User_ID = o.Max_User_ID) END Creator
      FROM   (SELECT
                     o.Inst_ID, o.Status, o.Name, o.NameSpace,
                     COUNT(*)                     Result_Count,
                     SUM(Space_Overhead)/1024     Space_Overhead_KB,
                     SUM(Space_Unused)/1024       Space_Unused_KB,
                     MIN(Creation_Timestamp)      Min_CreationTS,
                     MAX(Creation_Timestamp)      Max_CreationTS,
                     MIN(Creator_UID) KEEP (DENSE_RANK FIRST ORDER BY Creation_Timestamp) Min_User_ID,
                     MAX(Creator_UID) KEEP (DENSE_RANK LAST  ORDER BY Creation_Timestamp) Max_User_ID,
                     COUNT(DISTINCT Creator_UID)  Creator_Count,
                     MAX(Depend_Count)            Depend_Count,
                     SUM(Block_Count)             Block_Count,
                     SUM(Pin_Count)               Pin_Count,
                     SUM(Scan_Count)              Scan_Count,
                     MIN(Row_Size_Min)            Row_Size_Min,
                     MAX(Row_Size_Max)            Row_Size_Max,
                     SUM(Row_Size_Avg*Row_Count)/DECODE(SUM(Row_Count), 0, 1, SUM(Row_Count))   Row_Size_Avg,
                     SUM(Build_Time)              Build_Time
              FROM   gv$Result_Cache_Objects o
              WHERE  Type = 'Result'
              #{@instance ? " AND Inst_ID = ?" : ""}
              GROUP BY Inst_ID, Status, Name, NameSpace
            ) o
      ORDER BY Space_Overhead_KB+Space_Unused_KB DESC", @instance]

    render_partial
  end

  def list_result_cache_single_results
    @instance   = params[:instance]
    @status     = params[:status]
    @name       = params[:name]
    @namespace  = params[:namespace]

    @results = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName
      FROM   gv$Result_Cache_Objects o
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      WHERE  Inst_ID   = ?
      AND    Status    = ?
      AND    Name      = ?
      AND    NameSpace = ?
      AND    Type      = 'Result'
      ", @instance, @status, @name,@namespace]

    render_partial
  end

  def list_result_cache_dependencies_by_id
    @instance   = params[:instance]
    @id         = params[:id]
    @status     = params[:status]
    @name       = params[:name]
    @namespace  = params[:namespace]

    @dependencies =  sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName,
             j.Object_Type
      FROM   gV$RESULT_CACHE_DEPENDENCY d
      JOIN   gv$Result_Cache_Objects o ON o.Inst_ID = d.Inst_ID AND o.ID = d.Depend_ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      LEFT OUTER JOIN DBA_objects j ON j.Object_ID = o.Object_No
      WHERE  d.Inst_ID    = ?
      AND    d.Result_ID  = ?
      AND    o.Type       = 'Dependency'
      ", @instance, @id]

    render_partial :list_result_cache_dependencies
  end

  def list_result_cache_dependencies_by_name
    @instance   = params[:instance]
    @status     = params[:status]
    @name       = params[:name]
    @namespace  = params[:namespace]

    @dependencies =  sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName,
             j.Object_Type
      FROM   (SELECT /*+ NO_MERGE */ d.Inst_ID, d.Depend_ID
              FROM  gv$Result_Cache_Objects r
              JOIN  gV$RESULT_CACHE_DEPENDENCY d ON d.Inst_ID = r.Inst_ID AND d.Result_ID = r.ID
              WHERE r.Inst_ID   = ?
              AND   r.Status    = ?
              AND   r.Name      = ?
              AND   r.NameSpace = ?
              GROUP BY d.Inst_ID, d.Depend_ID
             ) d
      JOIN   gv$Result_Cache_Objects o ON o.Inst_ID = d.Inst_ID AND o.ID = d.Depend_ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      LEFT OUTER JOIN DBA_objects j ON j.Object_ID = o.Object_No
      WHERE  o.Type       = 'Dependency'
      ", @instance, @status, @name, @namespace]


    render_partial :list_result_cache_dependencies
  end

  def list_result_cache_dependents
    @instance   = params[:instance]
    @id         = params[:id]                     # ID des Dependency-Records in gv$Result_Cache_Objects
    @status     = params[:status]
    @name       = params[:name]                   # Name der Dependency
    @namespace  = params[:namespace]


    @results = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName
      FROM   gV$RESULT_CACHE_DEPENDENCY d
      JOIN   gv$Result_Cache_Objects o ON o.Inst_ID = d.Inst_ID AND o.ID = d.Result_ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      WHERE  d.Inst_ID    = ?
      AND    d.Depend_ID  = ?
      AND    o.Type      = 'Result'
      ", @instance, @id]

    render_partial :list_result_cache_single_results
  end

  def list_db_cache_advice_historic
    @instance = prepare_param_instance
    unless @instance
      show_popup_message "Instance number should not be empty"
      return
    end


    save_session_time_selection  # werte in session puffern in @time_selection_start, @time_selection_end

    get_instance_min_max_snap_id(@time_selection_start, @time_selection_end, @instance)   # @min_snap_id, @max_snap_id belegen

    rows = sql_select_all ["SELECT *
                            FROM   (
                                    SELECT ss.Begin_Interval_Time, h.Snap_ID,
                                           h.Size_For_Estimate Buffer_Cache_MB,
                                           ROUND(h.Size_Factor,1) Size_Factor,
                                           h.Physical_Reads -  LAG(h.Physical_Reads,    1, Physical_Reads)     OVER (PARTITION BY h.Instance_Number, Size_Factor ORDER BY h.Snap_ID) Phys_Reads_Delta
                                           FROM   DBA_Hist_DB_Cache_Advice h
                                           JOIN   DBA_Hist_Snapshot ss ON ss.DBID=h.DBID AND ss.Instance_Number=h.Instance_Number AND ss.Snap_ID=h.Snap_ID
                                           WHERE  h.DBID            = ?
                                           AND    h.Instance_Number = ?
                                           AND    h.Snap_ID         BETWEEN ? AND ?
                                   )
                            WHERE Snap_ID >= ?
                            ORDER BY snap_id, Size_Factor
                           ", prepare_param_dbid, @instance, @min_snap_id-1, @max_snap_id, @min_snap_id]

    results = []
    columns = {}

    if rows.count > 0     # letzten Record sichern
      res = {"begin_interval_time" => rows[0].begin_interval_time}
      rows.each do |r|
        if res["begin_interval_time"] != r.begin_interval_time
          res.extend SelectHashHelper
          results << res
          res = {"begin_interval_time" => r.begin_interval_time}                # Neuer Result-Record
        end
        res[r.buffer_cache_mb] = r.phys_reads_delta
        columns[r.size_factor] = r.buffer_cache_mb                              # Existenz der Spalte merken
        if r.size_factor == 1                                                   # Merken der Ist-Werte (size_factor=1)
          res["phys_reads_delta_1"] = r.phys_reads_delta
          res["buffer_cache_mb_1"]  = r.buffer_cache_mb
        end
      end
      res.extend SelectHashHelper
      results << res
    end


    column_options =
        [
            {:caption=>"Start",       :data=>proc{|rec| localeDateTime(rec.begin_interval_time)},              :title=>"Start of considered time slice", :plot_master_time => true},
        ]

    columns.each do |key, value|
      column_options << {:caption=>key.to_s,       :data=>proc{|rec| fn(rec[value])},     :title => "Estimated number of physical (non-cached) reads if cache size would be #{fn(value)} MB (factor #{key})", :data_title=>proc{|rec|"%t instead of #{fn(rec.buffer_cache_mb_1)} MB (#{fn(rec[value]*100.0/rec.phys_reads_delta_1) if rec[value] && rec.phys_reads_delta_1 && rec.phys_reads_delta_1 > 0} % compared to actual number)"} }
    end

    output = gen_slickgrid(results, column_options, {
        :caption => "Estimated number of read requests if size of DB buffer cache is changed with factor x",
        :max_height => 450,
        :multiple_y_axes => false
    })

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j output }');"}
    end
  end

  # List cache-Entries of object
  def list_db_cache_by_object_id
    @object_row = sql_select_first_row ['SELECT * FROM DBA_Objects WHERE Object_ID=?', params[:object_id]]
    raise "No object found in DBA_Objects for Object_ID=#{params[:object_id]}" unless @object_row

    @caches = sql_select_all ["
      SELECT x.Inst_ID,
             SUM(x.Blocks * ts.BlockSize)/(1024*1024) MB_Total,
             SUM(x.Blocks * ts.BlockSize)/(SELECT Value FROM gv$SGA s WHERE s.Inst_ID = x.Inst_ID AND s.Name = 'Database Buffers')*100 Pct,
             SUM(Blocks) Blocks,
             SUM(Dirty)  Dirty,
             SUM(xcur)   xcur,
             SUM(scur)   scur,
             SUM(cr)     cr,
             SUM(read)   read
      FROM   (
              SELECT c.Inst_ID, TS#, COUNT(*) Blocks,
                     SUM(DECODE(c.Dirty, 'Y', 1, 0)) Dirty,
                     SUM(DECODE(c.Status, 'xcur', 1, 0)) xcur,
                     SUM(DECODE(c.Status, 'scur', 1, 0)) scur,
                     SUM(DECODE(c.Status, 'cr', 1, 0)) cr,
                     SUM(DECODE(c.Status, 'read', 1, 0)) read
              FROM   DBA_Objects o
              JOIN   gv$BH c ON c.Objd = o.Data_Object_ID
              WHERE  o.Object_ID = ?
              GROUP BY c.Inst_ID, TS#
             ) x
      JOIN   sys.TS$ ts ON ts.TS# = x.TS#
      GROUP BY Inst_ID
    ", params[:object_id]]

    render_partial :list_db_cache_by_object_id
  end

  def list_sql_area_memory
    @instance = params[:instance]
    @max_rows_in_result=1000

    @sga_mems = sql_select_iterator ["
      SELECT CASE WHEN RowNum < #{@max_rows_in_result} THEN SQL_ID ELSE '[ Others ]' END                   SQL_ID,
             MIN(CASE WHEN RowNum < #{@max_rows_in_result} THEN SQL_Text ELSE '[ Others ]' END)            SQL_Text,
             MIN(CASE WHEN RowNum < #{@max_rows_in_result} THEN Parsing_Schema_Name ELSE '[ Others ]' END) Parsing_Schema_Name,
             SUM(Sharable_Mem)/1024                                                                        Sharable_Mem_KB,
             SUM(Persistent_Mem)/1024                                                                      Persistent_Mem_KB,
             SUM(Runtime_Mem)/1024                                                                         Runtime_Mem_KB,
             COUNT(*)                                                                                      Record_Count
      FROM   (SELECT SQL_ID, SUBSTR(SQL_Text, 1, 40) SQL_Text, Parsing_Schema_Name, Sharable_Mem, Persistent_Mem, Runtime_Mem
              FROM   gv$SQLArea
              WHERE  Inst_ID = ?
              ORDER BY Sharable_Mem DESC
             )
      GROUP BY CASE WHEN RowNum < #{@max_rows_in_result} THEN SQL_ID ELSE '[ Others ]' END
      ORDER BY 4 DESC
    ", @instance]

    render_partial
  end

  def list_object_cache_detail
    @instance   = params[:instance]
    @type       = params[:type]
    @namespace  = params[:namespace]
    @db_link    = params[:db_link]
    @kept       = params[:kept]
    @max_rows_in_result=1000
    @order_by   = params[:order_by]

    @object_caches = sql_select_iterator ["
      SELECT *
      FROM   (
              SELECT SUM(Sharable_Mem)  Sharable_Mem,
                     SUM(Record_Count)  Record_Count,
                     SUM(Child_Latches) Child_Latches,
                     SUM(Loads)         Loads,
                     SUM(Locks)         Locks,
                     SUM(Pins)          Pins,
                     SUM(Invalidations) Invalidations,
                     CASE WHEN RowNum < #{@max_rows_in_result} THEN Owner ELSE '[ Others ]' END Owner,
                     CASE WHEN RowNum < #{@max_rows_in_result} THEN Name  ELSE '[ Others ]' END Name
              FROM   (SELECT *
                      FROM   (SELECT Owner, Name,
                                     SUM(Sharable_Mem)            Sharable_Mem,
                                     COUNT(*)                     Record_Count,
                                     COUNT(DISTINCT Child_Latch)  Child_Latches,
                                     SUM(Loads)                   Loads,
                                     SUM(Locks)                   Locks,
                                     SUM(Pins)                    Pins,
                                     SUM(Invalidations)           Invalidations
                              FROM   gv$DB_Object_Cache
                              WHERE  Inst_ID    = ?
                              AND    Type       = ?
                              AND    Namespace  = ?
                              AND    DECODE(DB_Link, ?, 1, 0) = 1
                              AND    Kept       = ?
                              GROUP BY Owner, Name
                             )
                      ORDER BY #{@order_by} DESC
                     )
              GROUP BY CASE WHEN RowNum < #{@max_rows_in_result} THEN Owner ELSE '[ Others ]' END, CASE WHEN RowNum < #{@max_rows_in_result} THEN Name  ELSE '[ Others ]' END
             )
      ORDER BY #{@order_by} DESC
    ", @instance, @type, @namespace, @db_link, @kept]

    render_partial
  end


  # Existierende SQL-Profiles
  def show_profiles
    @profiles = sql_select_iterator "SELECT p.*, em.SGA_Usages, awr.AWR_Usages
                                     FROM   DBA_SQL_Profiles p
                                     LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ SQL_Profile, COUNT(*) SGA_Usages
                                                        FROM   gv$SQLArea
                                                        WHERE  SQL_profile IS NOT NULL
                                                        GROUP BY SQL_Profile
                                                       ) em ON em.SQL_Profile = p.Name
                                     LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ SQL_Profile, COUNT(DISTINCT SQL_ID) AWR_Usages
                                                        FROM   DBA_Hist_SQLStat
                                                        WHERE  SQL_profile IS NOT NULL
                                                        GROUP BY SQL_Profile
                                                       ) awr ON awr.SQL_Profile = p.Name
                                    "
    render_partial
  end

  def list_sql_profile_sqltext
    @sql = sql_select_one ["SELECT SQL_Text FROM  DBA_SQL_Profiles WHERE Name = ?", params[:profile_name]]
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('<pre style=\"background-color: lightyellow;  white-space: pre-wrap;\">#{my_html_escape(@sql)}</pre>');" }
    end

  end

  # Existierende SQL-Plan Baselines
  def show_plan_baselines
    @baselines = sql_select_iterator "SELECT b.*, em.SGA_Usages
                                      FROM   DBA_SQL_Plan_Baselines b
                                      LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ SQL_Plan_Baseline, COUNT(*) SGA_Usages
                                                         FROM   gv$SQLArea
                                                         WHERE  SQL_Plan_Baseline IS NOT NULL
                                                         GROUP BY SQL_Plan_Baseline
                                                        ) em ON em.SQL_Plan_Baseline = b.Plan_Name
                                     "
    render_partial
  end

  def list_sql_plan_baseline_sqltext
    @sql = sql_select_one ["SELECT SQL_Text FROM  DBA_SQL_Plan_Baselines WHERE Plan_Name = ?", params[:plan_name]]
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('<pre style=\"background-color: lightyellow;  white-space: pre-wrap;\">#{my_html_escape(@sql)}</pre>');" }
    end

  end


  # Existierende stored outlines
  def show_stored_outlines
    @outlines = sql_select_iterator "SELECT * FROM DBA_Outlines"
    render_partial
  end


  def list_dbms_xplan_display
    instance        = params[:instance]
    sql_id          = params[:sql_id]
    child_number    = params[:child_number]
    child_address   = params[:child_address]

    @plans = sql_select_all ["
      SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
                            'gv$sql_plan_statistics_all',
                            NULL,
                            'ADVANCED ALLSTATS LAST',
                            'inst_id = #{instance} AND sql_id = ''#{sql_id}'' AND child_number = #{child_number} AND Child_Address=HEXTORAW(''#{child_address}'')'
                          ))"]
    render_partial
  end

  def list_sql_monitor
    instance    = params[:instance]
    sid         = params[:sid]
    serialno    = params[:serialno]
    sql_id      = params[:sql_id]
    sql_exec_id = params[:sql_exec_id]

    result = sql_select_one ["SELECT DBMS_SQLTUNE.report_sql_monitor(
                                      sql_id          => ?,
                                      Session_ID      => ?,
                                      Session_Serial  => ?,
                                      SQL_Exec_ID     => ?,
                                      Inst_ID         => ?,
                                      --type            => 'HTML',
                                      type            => 'ACTIVE',
                                      report_level    => 'ALL'
                                    )
                             FROM dual", sql_id, sid, serialno, sql_exec_id, instance]

    if request.original_url['https://']                                         # Request kommt mit https, dann müssen <script>-Includes auch per https abgerufen werden, sonst wird page geblockt wegen insecure content
      result.gsub!(/http:/, 'https:')
    end

    render :text => result
  end

  def list_sql_monitor_sessions
    @instance         = params[:instance]
    @sql_id           = params[:sql_id]
    @plan_hash_value  = params[:plan_hash_value]
    @sid              = params[:sid]
    @serialno         = params[:serialno]

    where_string = ''
    where_values = []

    if @instance
      where_string << " AND Inst_ID = ?"
      where_values << @instance
    end

    if @sql_id
      where_string << " AND SQL_ID = ?"
      where_values << @sql_id
    end

    if @plan_hash_value
      where_string << " AND SQL_Plan_Hash_Value = ?"
      where_values << @plan_hash_value
    end

    if @sid
      where_string << " AND SID = ?"
      where_values << @sid
    end

    if @serialno
      where_string << " AND Session_Serial# = ?"
      where_values << @serialno
    end

    @sql_monitor_records = sql_select_all ["SELECT /* Panorama-Tool Ramm */
                                                   SQL_ID, SQL_Exec_Start, SQL_Exec_ID,
                                                   CASE WHEN COUNT(DISTINCT Inst_ID) > 1 THEN '<'||COUNT(DISTINCT Inst_ID)||'>' ELSE TO_CHAR(MIN(Inst_ID)) END Inst_ID,
                                                   CASE WHEN COUNT(DISTINCT Status) > 1 THEN  '<'||COUNT(DISTINCT Status) ||'>' ELSE MIN(Status) END Status,
                                                   MIN(RAWTOHEX(SQL_Child_Address))       Hex_SQL_Child_Address,
                                                   MIN(First_Refresh_Time)                First_Refresh_Time,
                                                   MAX(Last_Refresh_Time)                 Last_Refresh_Time,
                                                   MAX(Refresh_Count)                     Refresh_Count,
                                                   MAX(CASE WHEN Process_Name = 'ora' THEN SID END) SID,   /* SID des QC */
                                                   MIN(SQL_Plan_hash_Value)               SQL_Plan_Hash_Value,
                                                   MAX(CASE WHEN Process_Name = 'ora' THEN Session_Serial# END) Session_Serial#,   /* Session_Serial# des QC */
                                                   SUM(ELAPSED_TIME)                      ELAPSED_TIME,
                                                   SUM(CPU_TIME)                          CPU_TIME,
                                                   SUM(FETCHES)                           FETCHES,
                                                   SUM(BUFFER_GETS)                       BUFFER_GETS,
                                                   SUM(DISK_READS)                        DISK_READS,
                                                   SUM(DIRECT_WRITES)                     DIRECT_WRITES,
                                                   SUM(APPLICATION_WAIT_TIME)             APPLICATION_WAIT_TIME,
                                                   SUM(CONCURRENCY_WAIT_TIME)             CONCURRENCY_WAIT_TIME,
                                                   SUM(CLUSTER_WAIT_TIME)                 CLUSTER_WAIT_TIME,
                                                   SUM(USER_IO_WAIT_TIME)                 USER_IO_WAIT_TIME,
                                                   SUM(PLSQL_EXEC_TIME)                   PLSQL_EXEC_TIME,
                                                   SUM(JAVA_EXEC_TIME)                    JAVA_EXEC_TIME
                                            FROM   gv$SQL_Monitor m
                                            WHERE  1=1 #{where_string}
                                            GROUP BY SQL_ID, SQL_EXEC_START, SQL_EXEC_ID
                                            HAVING SUM(DECODE(Process_Name, 'ora', 1, 0)) > 0 /* mindestens ein Record muss Process_Name = ora haben */
                                          "].concat(where_values)

    raise "No records found in gv$SQL_Monitor for SQL-ID='#{@sql_id}'#{", Instance=#{@instance}" if @instance}#{", Plan-Hash-Value=#{@plan_hash_value}" if @plan_hash_value}" if @sql_monitor_records.count == 0

    if @sql_monitor_records.count == 1
      params[:instance]   = @sql_monitor_records[0].inst_id
      params[:sid]        = @sql_monitor_records[0].sid
      params[:serialno]   = @sql_monitor_records[0]['session_serial#']
      params[:sql_id]     = @sql_monitor_records[0].sql_id
      params[:sql_exec_id]= @sql_monitor_records[0].sql_exec_id

      start_sql_monitor_in_new_window
    else
      render_partial
    end

  end

  def start_sql_monitor_in_new_window
    @instance     = params[:instance]
    @sid          = params[:sid]
    @serialno     = params[:serialno]
    @sql_id       = params[:sql_id]
    @sql_exec_id  = params[:sql_exec_id]

    record_count = sql_select_one ["SELECT /* Panorama-Tool Ramm */ count(*)
                                    FROM   gv$SQL_Monitor
                                    WHERE  Inst_ID          = ?
                                    AND    SID              = ?
                                    AND    Session_Serial#  = ?
                                    AND    SQL_ID           = ?
                                    AND    SQL_Exec_ID      = ?",
                                   @instance, @sid, @serialno, @sql_id, @sql_exec_id]

    if record_count == 0
      show_popup_message "No data found in gv$SQL_Monitor for Instance=#{@instance}, SID=#{@sid}, Serial#=#{@serialno}, SQL-ID='#{@sql_id}', SQL_Exec_ID=#{@sql_exec_id}"
    else
      @button_id = get_unique_area_id
      render_partial(:start_sql_monitor_in_new_window, "jQuery('##{@button_id}').click();")
    end
  end

end
