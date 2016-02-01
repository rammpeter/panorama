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
                #{modus=="GV$SQL" ? ", s.Child_Number" : ", c.Child_Number" }
           FROM #{modus} s
           JOIN DBA_USERS u ON u.User_ID = s.Parsing_User_ID
           JOIN (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, COUNT(*) Child_Count, MIN(Child_Number) Child_Number, COUNT(DISTINCT Plan_Hash_Value) Plans
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
  def fill_sql_sga_stat(modus, instance, sql_id, object_status, child_number=nil, parsing_schema_name=nil)
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
                #{modus=="GV$SQL" ? "Child_Number," : "" }
                (SELECT COUNT(*) FROM GV$SQL c WHERE c.Inst_ID = s.Inst_ID AND c.SQL_ID = s.SQL_ID) Child_Count,
                s.Plan_Hash_Value, s.Optimizer_Env_Hash_Value, s.Module, s.Action, s.Inst_ID,
                s.Parsing_Schema_Name,
                o.Owner||'.'||o.Object_Name Program_Name, o.Object_Type Program_Type, o.Last_DDL_Time Program_Last_DDL_Time,
                s.Program_Line# Program_LineNo,
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

  # Existierende SQL-Profiles, Parameter: Result-Zeile eines selects
  def get_sql_profiles(sql_row)
    sql_select_all ["SELECT * FROM DBA_SQL_Profiles WHERE Signature = TO_NUMBER(?) OR  Signature = TO_NUMBER(?)",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s] if sql_row
  end

  # Existierende SQL-Plan Baselines, Parameter: Result-Zeile eines selects
  def get_sql_plan_baselines(sql_row)
    if get_db_version >= "11.2"
      sql_select_all ["SELECT * FROM DBA_SQL_Plan_Baselines WHERE Signature = TO_NUMBER(?) OR  Signature = TO_NUMBER(?)",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s] if sql_row
    else
      []
    end
  end

  # Existierende stored outlines, Parameter: Result-Zeile eines selects
  def get_sql_outlines(sql_row)
    sql_select_all ["SELECT * FROM DBA_Outlines WHERE Signature = UTL_RAW.Cast_From_Number(TO_NUMBER(?)) OR  Signature = UTL_RAW.Cast_From_Number(TO_NUMBER(?))",
                    sql_row.exact_signature.to_s, sql_row.force_signature.to_s] if sql_row
  end

  public

  # Erzeugt Daten für execution plan
  def get_sga_execution_plan(modus, sql_id, instance, child_number)
    plans = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Operation, Options, Object_Owner, Object_Name, Object_Type,
          CASE WHEN p.ID = 0 THEN (SELECT Optimizer    -- Separater Zugriff auf V$SQL_Plan, da nur dort die Spalte Optimizer gefüllt ist
                                    FROM  gV$SQL_Plan sp
                                    WHERE sp.SQL_ID       = p.SQL_ID
                                    AND   sp.Inst_ID      = p.Inst_ID
                                    AND   sp.Child_Number = p.Child_Number
                                    AND   sp.ID           = 0
                                   ) ELSE NULL END Optimizer,
          DECODE(Other_Tag,
                 'PARALLEL_COMBINED_WITH_PARENT', 'PCWP',
                 'PARALLEL_COMBINED_WITH_CHILD' , 'PCWC',
                 'PARALLEL_FROM_SERIAL',          'S > P',
                 'PARALLEL_TO_PARALLEL',          'P > P',
                 'PARALLEL_TO_SERIAL',            'P > S',
                 Other_Tag
                ) Parallel_Short,
          Other_Tag Parallel,
          Depth, Access_Predicates, Filter_Predicates, Projection, p.temp_Space/(1024*1024) Temp_Space_MB, Distribution,
          ID, Parent_ID, Executions,
          Last_Starts, Starts, Last_Output_Rows, Output_Rows, Last_CR_Buffer_Gets, CR_Buffer_Gets,
          Last_CU_Buffer_Gets, CU_Buffer_Gets, Last_Disk_Reads, Disk_Reads, Last_Disk_Writes, Disk_Writes,
          Last_Elapsed_Time/1000 Last_Elapsed_Time, Elapsed_Time/1000 Elapsed_Time,
          p.Cost, p.Cardinality, p.Bytes, p.Partition_Start, p.Partition_Stop, p.Partition_ID, p.Time,
          NVL(t.Num_Rows, i.Num_Rows) Num_Rows,
          NVL(t.Last_Analyzed, i.Last_Analyzed) Last_Analyzed,
          (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner=p.Object_Owner AND s.Segment_Name=p.Object_Name) MBytes
          #{", a.DB_Time_Seconds, a.CPU_Seconds, a.Waiting_Seconds, a.Read_IO_Requests, a.Write_IO_Requests,
               a.IO_Requests, a.Read_IO_Bytes, a.Write_IO_Bytes, a.Interconnect_IO_Bytes, a.Min_Sample_Time, a.Max_Sample_Time  " if get_db_version >= "11.2"}
        FROM  gV$SQL_Plan_Statistics_All p
        LEFT OUTER JOIN DBA_Tables  t ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name
        LEFT OUTER JOIN DBA_Indexes i ON i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name
        #{" LEFT OUTER JOIN (SELECT SQL_PLan_Line_ID, SQL_Plan_Hash_Value,
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
                                    MAX(Sample_Time)                  Max_Sample_Time
                             FROM   gv$Active_Session_History
                             WHERE  SQL_ID  = ?
                             AND    Inst_ID = ?
                             #{modus == 'GV$SQL' ? 'AND    SQL_Child_Number = ?' : ''}   -- auch andere Child-Cursoren von PQ beruecksichtigen wenn Child-uebergreifend angefragt
                             GROUP BY SQL_Plan_Line_ID, SQL_Plan_Hash_Value
                 ) a ON a.SQL_Plan_Line_ID = p.ID AND a.SQL_Plan_Hash_Value = p.Plan_Hash_Value
          " if get_db_version >= "11.2"}
        WHERE SQL_ID  = ?
        AND   Inst_ID = ?
        AND   Child_Number = ?
        ORDER BY ID"
        ].concat(get_db_version >= "11.2" ? [sql_id, instance].concat(modus == 'GV$SQL' ? [child_number] : []) : []).concat([sql_id, instance, child_number])

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
    @object_status= params[:object_status]
    @object_status='VALID' unless @object_status  # wenn kein status als Parameter uebergeben, dann VALID voraussetzen
    @parsing_schema_name = params[:parsing_schema_name]

    @sql                 = fill_sql_sga_stat("GV$SQL", @instance, @sql_id, @object_status, @child_number, @parsing_schema_name)
    @sql_statement       = get_sga_sql_statement(@instance, @sql_id)
    @sql_profiles        = get_sql_profiles(@sql)
    @sql_plan_baselines  = get_sql_plan_baselines(@sql)
    @sql_outlines        = get_sql_outlines(@sql)

    @plans               = get_sga_execution_plan(@modus, @sql_id, @instance, @child_number)

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
      ORDER BY Position
      ", @instance, @sql_id, @child_number ]

    @open_cursors = get_open_cursor_count(@instance, @sql_id)

    respond_to do |format|
      format.js { if @sql
                    render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_sql_detail_sql_id_childno" }');"
                  else
                    render :js => "$('##{params[:update_area]}').html('');
                                   alert('#{j "Kein Treffer in GV$SQL gefunden für SQL_ID='#{@sql_id}', Instance=#{@instance}, Child_Number=#{@child_number}"}');
                                   "
                  end
                }
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

    sql_child_info = sql_select_first_row ["SELECT COUNT(DISTINCT plan_hash_value) Plan_Count,
                                                   MIN(Child_Number) Min_Child_Number
                                            FROM   gv$SQL
                                            WHERE  Inst_ID = ? AND SQL_ID = ?", @instance, @sql_id]

    @plans = get_sga_execution_plan('GV$SQLArea', @sql_id, @instance, sql_child_info.min_child_number) if sql_child_info.plan_count == 1 # Nur anzeigen wenn eindeutig immer der selbe plan

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
    @sums = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             Inst_ID, NVL(Pool, Name) Pool, sum(Bytes) Bytes
      FROM   gv$sgastat
      #{@instance ? "WHERE  Inst_ID = ?" : ""}
      GROUP BY Inst_ID, NVL(Pool, Name)
      ORDER BY 3 DESC", @instance]

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
              p.operation, p.options, p.access_predicates
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

  def list_object_nach_file_und_block
     @object = object_nach_file_und_block(params[:fileno], params[:blockno]) 
     #@object = "[Kein Object gefunden für Parameter FileNo=#{params[:fileno]}, BlockNo=#{params[:blockno]}]" unless @object
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
             u.UserName
      FROM   gV$RESULT_CACHE_DEPENDENCY d
      JOIN   gv$Result_Cache_Objects o ON o.Inst_ID = d.Inst_ID AND o.ID = d.Depend_ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
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
             u.UserName
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
            {:caption=>"Start",       :data=>proc{|rec| localeDateTime(rec.begin_interval_time)},              :title=>"Start of considered time range", :plot_master_time => true},
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
             SUM(Sharable_Mem)/1024                                                                       Sharable_Mem_KB,
             COUNT(*)                                                                                     Record_Count
      FROM   (SELECT SQL_ID, SUBSTR(SQL_Text, 1, 40) SQL_Text, Parsing_Schema_Name, Sharable_Mem
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
                     SUM(Loads)         Loads,
                     SUM(Locks)         Locks,
                     SUM(Pins)          Pins,
                     SUM(Invalidations) Invalidations,
                     CASE WHEN RowNum < #{@max_rows_in_result} THEN Owner ELSE '[ Others ]' END Owner,
                     CASE WHEN RowNum < #{@max_rows_in_result} THEN Name  ELSE '[ Others ]' END Name
              FROM   (SELECT *
                      FROM   (SELECT Owner, Name,
                                     SUM(Sharable_Mem)  Sharable_Mem,
                                     COUNT(*)           Record_Count,
                                     SUM(Loads)         Loads,
                                     SUM(Locks)         Locks,
                                     SUM(Pins)          Pins,
                                     SUM(Invalidations) Invalidations
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




end
