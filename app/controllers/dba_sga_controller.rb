# encoding: utf-8
class DbaSgaController < ApplicationController

  #require "dba_helper"   # Erweiterung der Controller um Helper-Methoden
  include DbaSgaHelper
  include DbaHelper
  include ExplainPlanHelper

  # Auflösung/Detaillierung der im Feld MODUL geührten Innformation
  def show_application_info
    info =explain_application_info(params[:org_text])
    if info[:short_info]
      explain_text = "#{info[:short_info]}<BR>#{info[:long_info]}"
    else
      explain_text = "nothing known for #{params[:org_text]}"        # Default
    end

    respond_to do |format|
      format.html {render :html => explain_text  }
    end
  end

  def show_sql_area_sql_id
    @filter = prepare_param :filter
    render_partial
  end

  def list_sql_area_sql_id  # Auswertung GV$SQLArea
    @modus = "GV$SQLArea"
    list_sql_area(@modus)
  end

  def list_sql_area_sql_id_childno # Auswertung GV$SQL
    @modus = "GV$SQL"
    list_sql_area(@modus)
  end

  def list_last_sql_from_sql_worksheet
    params[:maxResultCount] = 100
    params[:topSort] = 'LastActive'
    # params[:filter]  = params[:sql_statement]&.strip&.gsub(/;$/, '')
    params[:sql_id] = read_from_client_info_store(:last_used_worksheet_sql_id)

    params[:username] = sql_select_one "SELECT USER FROM DUAL"

    list_sql_area_sql_id                                                        # route to action
  end


  private
  def list_sql_area(modus)
    instance = prepare_param_instance

    @filters = {}
    @filters[:instance]     = instance              if instance
    @filters[:username]     = params[:username]     if prepare_param(:username)
    @filters[:sql_id]       = params[:sql_id]       if prepare_param(:sql_id)
    @filters[:filter]       = params[:filter]       if prepare_param(:filter)
    @filters[:sql_profile]  = params[:sql_profile]  if prepare_param(:sql_profile)
    @filters[:no_plsql]     = true                  unless prepare_param(:include_plsql)

    @sqls = fill_sql_area_list(modus, @filters,
                          params[:maxResultCount],
                          params[:topSort]
    )

    render_partial :list_sql_area
  end

  def fill_sql_area_list(modus, filters, max_result_count, top_sort) # Wird angesprungen aus Vor-Methode
    max_result_count = 100 unless max_result_count
    top_sort         = 'ElapsedTimeTotal' unless top_sort

    where_string = ""
    where_values = []

    if filters[:instance]
      where_string << " AND s.Inst_ID = ?"
      where_values << filters[:instance]
    end

    if filters[:username]
      where_string << " AND u.UserName = UPPER(?)"
      where_values << filters[:username]
    end

    if filters[:filter]
      where_string << " AND UPPER(SQL_FullText) LIKE UPPER('%'||?||'%')"
      where_values << filters[:filter]
    end
    if filters[:sql_id]
      where_string << " AND s.SQL_ID LIKE '%'||?||'%'"
      where_values << filters[:sql_id]
    end

    if filters[:sql_profile]
      where_string << " AND s.SQL_Profile = ?"
      where_values << filters[:sql_profile]
    end

    if filters[:no_plsql]
      where_string << " AND s.Command_Type != 47" # PL/SQL EXECUTE
    end

    where_values << max_result_count

    sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM (SELECT  SUBSTR(LTRIM(SQL_TEXT),1,40) SQL_Text,
                    s.SQL_Text Full_SQL_Text,
                    s.Inst_ID, #{"s.Con_ID, " if get_current_database[:cdb]} s.Parsing_Schema_Name,
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
                    CASE WHEN s.Buffer_Gets > 0 AND s.Disk_Reads < s.Buffer_Gets THEN
                    100 * (s.Buffer_Gets - s.Disk_Reads) / GREATEST(s.Buffer_Gets, 1) END Hit_Ratio,
                    TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS') First_Load_Time,
                    s.SHARABLE_MEM, s.PERSISTENT_MEM, s.RUNTIME_MEM,
                    ROUND(s.CPU_TIME / 1000000, 3) CPU_TIME_SECS,
                    ROUND(s.Cluster_Wait_Time / 1000000, 3) Cluster_Wait_Time_SECS,
                    ROUND((s.CPU_TIME / 1000000) / DECODE(s.EXECUTIONS, 0, 1, s.EXECUTIONS), 3) AS CPU_TIME_SECS_PER_EXECUTE,
                    s.SQL_ID, s.Plan_Hash_Value, s.Object_Status, s.Last_Active_Time,
                    c.Child_Count, c.Plans
                    #{modus=="GV$SQL" ? ", s.Child_Number, RAWTOHEX(s.Child_Address) Child_Address" : ", c.Child_Number, c.Child_Address, s.Version_Count" }
            FROM   #{modus} s
            JOIN DBA_USERS u ON u.User_ID = s.Parsing_User_ID
            JOIN (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, COUNT(*) Child_Count, MIN(Child_Number) Child_Number, MIN(RAWTOHEX(Child_Address)) Child_Address,
                         COUNT(DISTINCT Plan_Hash_Value) Plans
                  FROM   GV$SQL GROUP BY Inst_ID, SQL_ID
                 ) c ON c.Inst_ID=s.Inst_ID AND c.SQL_ID=s.SQL_ID
            WHERE 1 = 1 -- damit nachfolgende Klauseln mit AND beginnen können
                #{where_string}
                #{" AND Rows_Processed>0" if top_sort == 'BufferGetsPerRow'}
            ORDER BY #{sql_area_sort_criteria(modus)[top_sort.to_sym][:sql]}
           )
      WHERE ROWNUM < ?
      ORDER BY #{sql_area_sort_criteria(modus)[top_sort.to_sym][:sql]}
      "
    ].concat(where_values)
  end

  private
  # Modus enthält GV$SQL oder GV$SQLArea
  def fill_sql_sga_stat(modus, instance, sql_id, object_status, child_number=nil, parsing_schema_name=nil, child_address=nil, con_id=nil)
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

    if con_id
      where_string << " AND s.Con_ID = ?"
      where_values << con_id
    end

    sql = sql_select_first_row ["\
      SELECT /* Panorama-Tool Ramm */
                s.ELAPSED_TIME/1000000 ELAPSED_TIME_SECS,
                s.Inst_ID, s.Object_Status,
                s.DISK_READS,
                s.BUFFER_GETS,
                s.EXECUTIONS, Fetches,
                s.PARSE_CALLS, s.SORTS,
                s.Loads, s.Locked_Total, s.Pinned_Total,
                s.ROWS_PROCESSED, s.Invalidations,
                CASE WHEN s.Buffer_Gets > 0 AND s.Disk_Reads < s.Buffer_Gets THEN
                100 * (s.Buffer_Gets - s.Disk_Reads) / GREATEST(s.Buffer_Gets, 1) END Hit_Ratio,
                TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS') First_Load_Time,
                TO_DATE(s.Last_Load_Time, 'YYYY-MM-DD/HH24:MI:SS') Last_Load_Time,
                s.SHARABLE_MEM, s.PERSISTENT_MEM, s.RUNTIME_MEM,
                s.Last_Active_Time,
                s.CPU_TIME/1000000 CPU_TIME_SECS,
                s.Application_Wait_Time/1000000 Application_Wait_Time_secs,
                s.Concurrency_Wait_Time/1000000 Concurrency_Wait_Time_secs,
                s.Cluster_Wait_Time/1000000     Cluster_Wait_Time_secs,
                s.User_IO_Wait_Time/1000000     User_IO_Wait_Time_secs,
                s.PLSQL_Exec_Time/1000000       PLSQL_Exec_Time_secs,
                s.SQL_ID,
                #{modus=="GV$SQL" ? "Child_Number, RAWTOHEX(Child_Address) Child_Address, " : "" }
                s.Plan_Hash_Value, /* Enthaelt im Falle v$SQLArea nur einem von mehreren moeglichen Werten */
                s.Optimizer_Env_Hash_Value, s.Module, s.Action, s.Inst_ID,
                s.Parsing_Schema_Name, SQL_Profile,
                o.Owner Program_Owner, o.Object_Name Program_Name, o.Object_Type Program_Type, o.Last_DDL_Time Program_Last_DDL_Time,
                s.Program_Line# Program_LineNo, #{'SQL_Plan_Baseline, ' if get_db_version >= '11.2'}
                s.Exact_Matching_Signature /* DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_FullText, 0) */ Exact_Signature,
                s.Force_Matching_Signature /* DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_FullText, 1) */ Force_Signature
           FROM #{modus} s
           LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = s.Program_ID -- PL/SQL-Programm
           WHERE s.SQL_ID  = ? #{where_string}
           ", sql_id].concat where_values
    if sql.nil? && object_status
      sql = fill_sql_sga_stat(modus, instance, sql_id, nil, child_number, parsing_schema_name)
      add_statusbar_message("No SQL found with Object_Status='#{object_status}' in #{modus}. Filter Object_Status is supressed now.")
    end
    if sql.nil? && parsing_schema_name
      sql = fill_sql_sga_stat(modus, instance, sql_id, object_status, child_number, nil)
      add_statusbar_message("No SQL found with Parsing_Schema_Name='#{parsing_schema_name}' in #{modus}. Filter Parsing_Schema_Name is supressed now.")
    end

    return nil if sql.nil?

    if modus == "GV$SQL"
      sql[:child_count] = 1                                                    # not from DB
      sql[:plan_hash_value_count] = 1                                          # not from DB
    else
      sql_counts = sql_select_first_row ["SELECT COUNT(*) child_count, COUNT(DISTINCT Plan_Hash_Value) Plan_Hash_Value_Count,
                                                 MIN(TO_DATE(c.Last_Load_Time, 'YYYY-MM-DD/HH24:MI:SS')) Min_Last_Load_Time
                                          FROM   GV$SQL c
                                          WHERE c.Inst_ID = ? AND c.SQL_ID = ?", @instance, @sql_id]
      sql[:child_count]            = sql_counts.child_count
      sql[:plan_hash_value_count]  = sql_counts.plan_hash_value_count
      sql[:min_last_load_time]     = sql_counts.min_last_load_time
    end

    sql
  end

  # get sums over various records in gv$SQL
  def v_sql_sums(instance, sql_id, object_status, parsing_schema_name, con_id)
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

    if parsing_schema_name
      where_string << " AND s.Parsing_Schema_Name = ?"
      where_values << parsing_schema_name
    end

    if con_id
      where_string << " AND s.Con_ID = ?"
      where_values << con_id
    end

    sql_select_first_row ["\
      SELECT COUNT(*) Child_Count
      FROM   gv$SQL s
      WHERE  s.SQL_ID = ?
      #{where_string}
      ", sql_id].concat(where_values)
  end




    def get_open_cursor_count(instance, sql_id)
    sql_select_one ["\
        SELECT /* Panorama-Tool Ramm */ COUNT(*)
        FROM   gv$Open_Cursor o
        WHERE  o.Inst_ID = ?
        AND    o.SQL_ID  = ?",
        instance, sql_id]
  end

  def get_sql_bind_count(instance, sql_id, child_number = nil, child_address = nil)
    sql_select_one ["\
      SELECT COUNT(*)
      FROM   gv$SQL_Bind_Capture c
      WHERE  Inst_ID = ?
      AND    SQL_ID  = ?
      #{" AND Child_Number  = ?" unless child_number.nil?}
      #{" AND Child_Address = HEXTORAW(?)" unless child_address.nil?}
      ", instance, sql_id ]
                                .concat(child_number.nil?  ? [] : [child_number])
                                .concat(child_address.nil? ? [] : [child_address])
  end

  def get_execution_plan_count(instance, sql_id, child_number = nil, child_address = nil)
    result = sql_select_first_row ["\
      SELECT COUNT(DISTINCT Plan_Hash_Value) Plan_Hash_Values, COUNT(DISTINCT Object_Owner||'.'||Object_Name)-1 Objects
      FROM   gv$SQL_Plan
      WHERE  Inst_ID = ?
      AND    SQL_ID  = ?
      #{" AND Child_Number  = ?" unless child_number.nil?}
                    #{" AND Child_Address = HEXTORAW(?)" unless child_address.nil?}
      ", instance, sql_id ]
                       .concat(child_number.nil?  ? [] : [child_number])
                       .concat(child_address.nil? ? [] : [child_address])

    if result
      return result.plan_hash_values, result.objects
    else
      return nil, nil
    end
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
  #def get_sga_execution_plan(modus, sql_id, instance, child_number, child_address, restrict_ash_to_child)
  def list_sql_detail_execution_plan
    @sql_id                 = params[:sql_id]
    @instance               = prepare_param_instance
    @child_number           = (params[:child_number].nil? || params[:child_number] == '') ? nil : (params[:child_number].to_i rescue nil)
    @child_address          = params[:child_address] == '' ? nil : params[:child_address]
    @show_adaptive_plans     = prepare_param_int :show_adaptive_plans

    where_string = ''
    where_values = []

    if !@child_number.nil?
      where_string << ' AND Child_Number = ?'
      where_values << @child_number
    end

    if !@child_address.nil?
      where_string << ' AND Child_Address = HEXTORAW(?)'
      where_values << @child_address
    end

    @include_ash_in_sql = get_db_version >= "11.2" && (PackLicense.diagnostics_pack_licensed? || PackLicense.panorama_sampler_active?)

    @multiplans = sql_select_all ["\
      SELECT p.Plan_Hash_Value, COUNT(DISTINCT p.Child_Number) Child_Count, MIN(p.Child_Number) Min_Child_Number
      FROM   gv$SQL_Plan p
      WHERE  SQL_ID  = ?
      AND    Inst_ID = ?
      #{where_string}
      GROUP BY Plan_Hash_Value
      ", @sql_id, @instance].concat(where_values)

    if get_db_version >= '12.1'
      display_map_records = sql_select_all ["\
        SELECT plan_hash_Value, X.*
        FROM gv$sql_plan,
        XMLTABLE ( '/other_xml/display_map/row' passing XMLTYPE(other_xml ) COLUMNS
          op  NUMBER PATH '@op',    -- operation
          dis NUMBER PATH '@dis',   -- display
          par NUMBER PATH '@par',   -- parent
          prt NUMBER PATH '@prt',   -- unkown
          dep NUMBER PATH '@dep',   -- depth
          skp NUMBER PATH '@skp'    -- skip
        ) (+) AS X
        WHERE  SQL_ID = ?
        AND    Inst_ID = ?
        #{where_string}
        AND other_xml   IS NOT NULL
        ", @sql_id, @instance].concat(where_values)
    else
      display_map_records = []
    end

    all_plans = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.Object_Type, p.Object_Alias, p.QBlock_Name, p.Timestamp, p.Optimizer, p.Plan_Hash_Value,
          p.Other_Tag, p.Other_XML, p.Other, Version_Orange_Count, Version_Red_Count, Child_Number,
          Depth, Access_Predicates, Filter_Predicates, Projection, p.temp_Space/(1024*1024) Temp_Space_MB, Distribution,
          ID, Parent_ID, Executions, p.Search_Columns,
          Last_Starts, Starts, Last_Output_Rows, Output_Rows, Last_CR_Buffer_Gets, CR_Buffer_Gets,
          Last_CU_Buffer_Gets, CU_Buffer_Gets, Last_Disk_Reads, Disk_Reads, Last_Disk_Writes, Disk_Writes,
          Last_Elapsed_Time/1000 Last_Elapsed_Time, Elapsed_Time/1000 Elapsed_Time,
          p.Cost, p.Cardinality, p.CPU_Cost, p.IO_Cost, p.Bytes, p.Partition_Start, p.Partition_Stop, p.Partition_ID, p.Time,
          p.Policy, p.Estimated_Optimal_Size, p.Estimated_Onepass_Size, p.Last_Memory_Used, p.Last_Execution, p.Last_Degree,
          p.Total_Executions, p.Optimal_Executions, p.Onepass_Executions, p.Multipasses_Executions, p.Active_Time,
          p.Max_TempSeg_Size, p.Last_Tempseg_Size,
          NVL(t.Num_Rows, i.Num_Rows) Num_Rows,
          NVL(t.Last_Analyzed, i.Last_Analyzed) Last_Analyzed,
          o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_TS,
          (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner=p.Object_Owner AND s.Segment_Name=p.Object_Name) MBytes
          #{", a.DB_Time_Seconds, a.CPU_Seconds, a.Waiting_Seconds, a.Read_IO_Requests, a.Write_IO_Requests,
               a.IO_Requests, a.Read_IO_Bytes, a.Write_IO_Bytes, a.Interconnect_IO_Bytes, a.Min_Sample_Time, a.Max_Sample_Time, a.Max_Temp_ASH_MB, a.Max_PGA_ASH_MB, a.Max_PQ_Sessions " if @include_ash_in_sql}
        FROM   (SELECT /*+ NO_MERGE */ p.*,
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
                FROM   gV$SQL_Plan_Statistics_All p
                WHERE  p.Inst_ID         = ?
                AND    p.SQL_ID          = ?
                #{where_string}
               ) p
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
                                     WHERE  SQL_ID              = ?
                                     AND    Inst_ID             = ?
                                     #{"AND SQL_Child_Number = ?" if !@child_number.nil?}   -- auch andere Child-Cursoren von PQ beruecksichtigen wenn Child-uebergreifend angefragt
                                     GROUP BY SQL_Plan_Line_ID, SQL_Plan_Hash_Value, NVL(QC_Session_ID, Session_ID), Sample_ID   -- Alle PQ-Werte mit auf Session kumulieren
                                    )
                             GROUP BY SQL_Plan_Line_ID, SQL_Plan_Hash_Value
                 ) a ON a.SQL_Plan_Line_ID = p.ID AND a.SQL_Plan_Hash_Value = p.Plan_Hash_Value
          " if @include_ash_in_sql}
        -- Object_Type ensures that only one record is gotten from DBA_Objects even if object is partitioned
        -- Content after blank does not matter for object_type (like 'INDEX (UNIQUE)')
        LEFT OUTER JOIN DBA_Objects o ON o.Owner = p.Object_Owner AND o.Object_Name = p.Object_Name AND o.Object_Type = DECODE(INSTR(p.Object_Type, ' '), 0, p.Object_Type, SUBSTR(p.Object_Type, 1, INSTR(p.Object_Type, ' ')-1))
        ORDER BY ID
        ", @instance, @sql_id]
                                   .concat(where_values)
                                   .concat(@include_ash_in_sql ? [@sql_id, @instance].concat(!@child_number.nil? ? [@child_number] : []) : [])


    @multiplans.each do |mp|
      mp['elapsed_secs_per_exec'] = sql_select_one ["\
        SELECT CASE WHEN SUM(Executions) = 0 THEN 0 ELSE SUM(Elapsed_Time)/1000000 / SUM(Executions) END
        FROM   gv$SQL
        WHERE  SQL_ID           = ?
        AND    Inst_ID          = ?
        AND    Plan_Hash_Value  = ?
        #{where_string}
        ", @sql_id, @instance, mp.plan_hash_value].concat(where_values)

      mp[:plans] = ajust_plan_records_for_adaptive(plan:                  mp,
                                                   plan_lines:            all_plans,
                                                   display_map_records:   display_map_records,
                                                   show_adaptive_plans:    @show_adaptive_plans
      )
      calculate_execution_order_in_plan(mp[:plans])                             # Calc. execution order by parent relationship

      # Segmentation of XML document

      other_xml = nil
      mp[:plans].each do |p|
        other_xml = p.other_xml if get_db_version >= "11.2" && !p.other_xml.nil?  # Only one record per plan has values
      end

      mp[:plan_additions] = []
      begin
        xml_doc = Nokogiri::XML(other_xml)
        xml_doc.xpath('//info').each do |info|
          mp[:plan_additions] << ({
              :record_type  => 'Info',
              :attribute    => info.attributes['type'].to_s,
              :value        => info.children.text
          }.extend SelectHashHelper)
        end

        xml_doc.xpath('//bind').each do |bind|
          attributes = ''
          bind.attributes.each do |key, val|
            attributes << "#{key}=#{val} "
          end

          mp[:plan_additions] << ({
              :record_type  => 'Peeked bind',
#              :attribute    => Hash[bind.attributes.map {|key, val| [key, val.to_s]}].to_s,
              :attribute    => attributes,
              :value        => bind.children.text
          }.extend SelectHashHelper)
        end

        xml_doc.xpath('//hint').each do |hint|
          mp[:plan_additions] << ({
              :record_type  => 'Hint',
              :attribute    => nil,
              :value        => hint.children.text
          }.extend SelectHashHelper)
        end

        xml_doc.xpath('//display_map/row').each do |dm|
          attributes = ''
          dm.attributes.each do |key, val|
            attributes << "#{key}=#{val} "
          end

          mp[:plan_additions] << ({
            :record_type  => 'Display Map',
            :attribute    => nil,
            :value        => attributes
          }.extend SelectHashHelper)
        end

      rescue Exception => e
        mp[:plan_additions] << ({
            :record_type  => 'Exception while processing XML document',
            :attribute => e.message,
            :value => my_html_escape(other_xml).gsub(/&lt;info/, "<br/>&lt;info").gsub(/&lt;hint/, "<br/>&lt;hint")
        }.extend SelectHashHelper)
      end

    end

    @additional_ash_message = nil
    if !@child_number.nil?
      child_count = sql_select_one ["SELECT COUNT(*) FROM gv$SQL WHERE Inst_ID = ? AND SQL_ID = ?", @instance, @sql_id]
      @additional_ash_message = "ASH-values are for child_number=#{@child_number} only but #{child_count} children exists for this SQL-ID and Instance" if child_count > 1
    end

    if @multiplans.count > 0
      render_partial :list_sql_detail_execution_plan
    else
      show_popup_message("No execution plan found for SQL ID = '#{@sql_id}'#{", instance = #{@instance}" if @instance}#{", child number = #{@child_number}" if @child_number}#{", child address = '#{@child_address}'" if @child_address}", :html)
    end
  end


  # Anzeige Einzeldetails des SQL
  def list_sql_detail_sql_id_or_history
    instance            = prepare_param_instance
    sql_id              = prepare_param(:sql_id)
    parsing_schema_name = prepare_param(:parsing_schema_name)
    con_id              = prepare_param(:con_id)

    where_string = ''
    where_values = []

    if instance
      where_string << " AND Inst_ID = ?"
      where_values << instance
    end

    if parsing_schema_name
      where_string << " AND Parsing_Schema_Name = ?"
      where_values << parsing_schema_name
    end

    if con_id
      where_string << " AND Con_ID = ?"
      where_values << con_id
    end

    sql_count = sql_select_one ["SELECT COUNT(*) FROM gv$SQLArea WHERE SQL_ID = ? #{where_string}", sql_id].concat(where_values)
    if sql_count > 0
      add_statusbar_message("SQL found in SGA! Showing content from SGA instead of AWR history.")
      list_sql_detail_sql_id
    else
      params[:statusbar_message] = "SQL not found in SGA! Showing history from AWR."
      redirect_to url_for(controller: :dba_history, action: :list_sql_detail_historic, params: params.permit! , method: :post)
    end

  end

  def list_sql_detail_sql_id_childno
    @time_selection_start = prepare_param :time_selection_start                 # alternative time range if SQL is not in SGA
    @time_selection_end   = prepare_param :time_selection_end                   # alternative time range if SQL is not in SGA
    @modus = "GV$SQL"   # Detaillierung SQL-ID, ChildNo
    @dbid         = prepare_param_dbid
    @instance     = prepare_param_instance
    @sql_id       = params[:sql_id]
    @child_number = params[:child_number].to_i
    @child_address  = prepare_param :child_address
    @object_status= params[:object_status]
    @object_status='VALID' if @object_status.nil? || @object_status == ''  # wenn kein status als Parameter uebergeben, dann VALID voraussetzen
    @parsing_schema_name  = prepare_param :parsing_schema_name
    @con_id       = prepare_param :con_id


    @sql                  = fill_sql_sga_stat("GV$SQL", @instance, @sql_id, @object_status, @child_number, @parsing_schema_name, @child_address, @con_id)

    @v_sql_sums           = v_sql_sums(@instance, @sql_id, @object_status, @parsing_schema_name, @con_id)

    @sql_statement        = get_sga_sql_statement(@instance, @sql_id)
    @sql_bind_count       = get_sql_bind_count(@instance, @sql_id, @child_number, @child_address)
    @execution_plan_count, @plan_object_count = get_execution_plan_count(@instance, @sql_id, @child_number, @child_address)

    # PGA-Workarea-Nutzung
    @workareas = sql_select_all ["\
      SELECT /* Panorama Ramm */ w.*,
             s.Serial# Serial_No,
             sq.Serial# QCSerial_No
      FROM   gv$SQL_Workarea_Active w
      JOIN   gv$Session s ON s.Inst_ID=w.Inst_ID AND s.SID=w.SID
      LEFT OUTER JOIN gv$Session sq ON sq.Inst_ID=w.QCInst_ID AND sq.SID=w.QCSID
      WHERE  w.SQL_ID = ?
      ORDER BY w.QCSID, w.SID
      ",  @sql_id]

    @open_cursors         = get_open_cursor_count(@instance, @sql_id)

    if @sql
      @sql_monitor_reports_count = get_sql_monitor_count(@dbid, @instance, @sql_id, localeDateTime(@sql.first_load_time, :minutes), localeDateTime(Time.now, :minutes))

      render_partial :list_sql_detail_sql_id_childno
    else
      if @time_selection_start && @time_selection_end
        redirect_to url_for(controller: :dba_history, action: :list_sql_detail_historic, params: params.permit!, method: :post)
      else
        # Use format html for popup message to ensure working in test
        show_popup_message("#{t(:dba_sga_list_sql_detail_sql_id_childno_no_hit_msg, :default=>'No record found in GV$SQL for')} SQL_ID='#{@sql_id}', Instance=#{@instance}, Child_Number=#{@child_number}", :html)
      end
    end
  end

  # Details auf Ebene SQL_ID kumuliert über Child-Cursoren
  def list_sql_detail_sql_id
    @time_selection_start = prepare_param :time_selection_start                 # alternative time range if SQL is not in SGA
    @time_selection_end   = prepare_param :time_selection_end                   # alternative time range if SQL is not in SGA
    @dbid         = prepare_param_dbid
    @instance = prepare_param_instance
    @sql_id   = params[:sql_id].strip
    @object_status= params[:object_status]
    @object_status='VALID' if @object_status.nil? || @object_status == ''  # wenn kein status als Parameter uebergeben, dann VALID voraussetzen
    @parsing_schema_name  = prepare_param :parsing_schema_name
    @con_id  = prepare_param :con_id

    # Liste der Child-Cursoren
    @sqls = sql_select_all ["SELECT Inst_ID, Child_Number FROM gv$SQL WHERE SQL_ID = ?#{" AND Inst_ID = ?" if @instance}", @sql_id].concat(@instance ? [@instance]: [])

    if @sqls.count == 0
      if @time_selection_start && @time_selection_end
        redirect_to url_for(controller: :dba_history, action: :list_sql_detail_historic, params: params.permit!, method: :post)
        return
      else
        show_popup_message "SQL-ID '#{@sql_id}' not found in GV$SQL for instance = #{@instance} !"
        return
      end
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
      add_statusbar_message(t(:dba_sga_list_sql_detail_sql_id_only_one_child_msg, :default=>"Only one child record found in gv$SQL, therefore child level view directly choosen"))
      params[:instance]     = @instance
      params[:child_number] = @sqls[0].child_number
      list_sql_detail_sql_id_childno  # Anzeige der Child-Info
      return
    end

    @sql = fill_sql_sga_stat("GV$SQLArea", @instance, @sql_id, @object_status, nil, @parsing_schema_name, nil, @con_id)

    @sql_statement        = get_sga_sql_statement(@instance, params[:sql_id])
    @sql_bind_count       = get_sql_bind_count(@instance, @sql_id)
    @execution_plan_count, @plan_object_count = get_execution_plan_count(@instance, @sql_id)

    @open_cursors          = get_open_cursor_count(@instance, @sql_id)
    @sql_monitor_reports_count = get_sql_monitor_count(@dbid, @instance, @sql_id, localeDateTime(@sql.first_load_time, :minutes), localeDateTime(Time.now, :minutes))

    @sql_child_info = sql_select_first_row ["SELECT COUNT(DISTINCT plan_hash_value) Plan_Count,
                                                   MIN(Child_Number)          Min_Child_Number,
                                                   MIN(RAWTOHEX(Child_Address)) KEEP (DENSE_RANK FIRST ORDER BY Child_Number)   Min_Child_Address
                                            FROM   gv$SQL
                                            WHERE  Inst_ID = ? AND SQL_ID = ?", @instance, @sql_id]

    #@plans = get_sga_execution_plan('GV$SQLArea', @sql_id, @instance, sql_child_info.min_child_number, sql_child_info.min_child_address, false) if @sql_child_info.plan_count == 1 # Nur anzeigen wenn eindeutig immer der selbe plan

    if @sql_child_info.plan_count > 1
      add_statusbar_message("Multiple different execution plans exist for this SQL-ID!\nPlease select one SQL child number for exact execution plan of this child cursor.")
    end

    render_partial :list_sql_detail_sql_id
  end

  def list_sql_child_cursors
    @instance       = prepare_param_instance
    @sql_id         = params[:sql_id].strip

    @filters = {
        :instance => @instance,
        :sql_id   => @sql_id
    }

    # Liste der Child-Cursoren
    @modus = 'GV$SQL'
    @sqls = fill_sql_area_list(@modus, @filters, 1000, nil)

    render_partial :list_sql_area
  end

  def list_bind_variables
    @instance       = prepare_param_instance
    @sql_id         = params[:sql_id]
    @child_number   = params[:child_number]  == '' ? nil : params[:child_number]
    @child_address  = params[:child_address] == '' ? nil : params[:child_address]

    # Bindevariablen des Cursors
    @binds = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Child_Number, Name, Position, DataType_String, Last_Captured,
             CASE DataType_String
               WHEN 'TIMESTAMP' THEN TO_CHAR(ANYDATA.AccessTimestamp(Value_AnyData), '#{sql_datetime_minute_mask}')
               WHEN 'DATE'      THEN TO_CHAR(TO_DATE(Value_String, 'MM/DD/YYYY HH24:MI:SS'), '#{sql_datetime_second_mask}')
             ELSE Value_String END Value_String,
             Child_Number,
             NLS_CHARSET_NAME(Character_SID) Character_Set, Precision, Scale, Max_Length
      FROM   gv$SQL_Bind_Capture c
      WHERE  Inst_ID = ?
      AND    SQL_ID  = ?
      #{" AND Child_Number  = ?" unless @child_number.nil?}
      #{" AND Child_Address = HEXTORAW(?)" unless @child_address.nil?}
      ORDER BY Position
      ", @instance, @sql_id ]
                                .concat(@child_number.nil?  ? [] : [@child_number])
                                .concat(@child_address.nil? ? [] : [@child_address])
    render_partial
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
              o.*,
              s.SID,
              s.Serial# Serial_No,
              s.OSUser,
              s.Process,
              s.Machine,
              s.Program,
              s.Module,
              DECODE(o.SQL_ID, s.SQL_ID, 'Y', 'N') Stmt_Active
       FROM   gv$Open_Cursor o
       JOIN   gv$Session s ON s.Inst_ID = o.Inst_ID AND s.SAddr = o.SAddr AND s.SID = o.SID
       WHERE  o.Inst_ID = ?
       AND    o.SQL_ID  = ?
       ", @instance, @sql_id]

    render_partial
  end

  # SGA-Komponenten 
  def list_sga_components
    @instance        = prepare_param_instance
    @sums = sql_select_all ["\
      SELECT s.Inst_ID, s.Pool, s.Bytes, NULL Parameter, r.Resize_Ops
      FROM   (
              SELECT /*+ NO_MERGE */ Inst_ID, NVL(Pool, Name) Pool, sum(Bytes) Bytes
              FROM   gv$sgastat
              #{@instance ? "WHERE  Inst_ID = ?" : ""}
              GROUP BY Inst_ID, NVL(Pool, Name)
             ) s
      LEFT OUTER JOIN (
              SELECT Inst_ID, Component, COUNT(*) Resize_Ops
              FROM   (SELECT Inst_ID, CASE WHEN Component LIKE '%buffer cache' THEN 'buffer_cache' ELSE Component END Component
                      FROM   gv$SGA_Resize_Ops
                     )
              GROUP BY Inst_ID, Component
             ) r ON r.Inst_ID = s.Inst_ID AND r.Component = s.Pool
      ORDER BY s.Bytes DESC
      ", @instance]

    @sums.each do |s|
      s['parameter'] =
          case s.pool
            when 'buffer_cache' then "db_block_buffers = #{ fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'db_block_buffers']))}, db_cache_size = #{fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'db_cache_size']))}"
            when 'java pool'    then "java_pool_size = #{   fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'java_pool_size']))}"
            when 'large pool'   then "large_pool_size = #{  fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'large_pool_size']))}"
            when 'log_buffer'   then "log_buffer = #{       fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'log_buffer']))}"
            when 'shared pool'  then "shared_pool_size = #{ fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'shared_pool_size']))}"
            when 'streams pool' then "streams_pool_size = #{fn(sql_select_one(["SELECT Value FROM gv$Parameter WHERE Inst_ID = ? AND Name = ?", s.inst_id, 'streams_pool_size']))}"
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

  def list_resize_ops_per_component
    @instance        = prepare_param_instance
    @pool            = params[:pool]

    where_string = "Inst_ID = ? AND "
    where_values = [@instance]

    if @pool == 'buffer_cache'
      where_string << "Component LIKE '%buffer cache'"
    else
      where_string << "Component = ?"
      where_values << @pool
    end

    @ops = sql_select_iterator [
        "SELECT *
         FROM   gv$SGA_Resize_Ops
         WHERE  #{where_string}
         ORDER BY Start_Time
        ", ].concat(where_values)

    render_partial
  end

  def list_db_cache_content
    @instance        = prepare_param_instance
    raise PopupMessageException.new("Instance must be set") unless @instance
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
      #{PanoramaConnection.autonomous_database? ?
        "CROSS JOIN (SELECT #{PanoramaConnection.db_blocksize} Blocksize FROM DUAL) ts" : # No access on sys.TS$ for autonomous DB. Use default blocksize
        "LEFT OUTER JOIN   sys.TS$ ts ON ts.TS# = x.TS#"
      }
      GROUP BY x.Inst_ID, x.Status
      ", @instance]

    @total_status_blocks = 0                  # Summation der Blockanzahl des Caches
    @db_cache_global_sums.each do |c|
      @total_status_blocks += c.blocks
    end


    # Konkrete Objekte im Cache
    @objects = sql_select_all ["
      WITH BH AS (SELECT /*+ NO_MERGE MATERIALIZE*/
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
                  FROM   GV$BH
                  WHERE  Status != 'free'  /* dont show blocks of truncated tables */
                  AND   Inst_ID = ?
                  GROUP BY ObjD, TS#
      ),
      Plan_SQLs AS (SELECT /*+ NO_MERGE MATERIALIZE */ o.Owner, o.Object_Name, COUNT(DISTINCT p.SQL_ID) SQL_ID_Count
                           FROM   gv$SQL_Plan p
                           JOIN   DBA_Objects o ON o.Object_ID = p.Object#
                           WHERE  p.Object# IS NOT NULL
                           AND    p.Inst_ID = ?
                           GROUP BY o.Owner, o.Object_Name
                   ),
      Tablespaces AS (SELECT /*+ NO_MERGE MATERIALIZE */ t.ts#, t.Name, d.Block_Size BlockSize
                             FROM   v$Tablespace t
                             JOIN   DBA_Tablespaces d ON d.Tablespace_Name = t.Name
                     )
      SELECT /* Panorama-Tool Ramm */
             NVL(o.Owner,'[UNKNOWN]') Owner,
             NVL(o.Object_Name,'TS='||ts.Name) Object_Name,
             #{@show_partitions=="1" ? "o.SubObject_Name" : "''"} SubObject_Name,
             MIN(o.Object_Type) Object_Type,  -- MIN statt Aufnahme in GROUP BY
             MIN(CASE WHEN o.Object_Type LIKE 'INDEX%' THEN
                       (SELECT Table_Owner||'.'||Table_Name FROM DBA_Indexes i WHERE i.Owner = o.Owner AND i.Index_Name = o.Object_Name)
             ELSE NULL END) Table_Name, -- MIN statt Aufnahme in GROUP BY
             NVL(SUM(sqls.SQL_ID_Count),0)  SQL_ID_Count,
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
      FROM   BH
      LEFT OUTER JOIN DBA_Objects o  ON o.Data_Object_ID = bh.ObjD
      LEFT OUTER JOIN Tablespaces ts ON ts.TS# = bh.TS#
      LEFT OUTER JOIN Plan_SQLs sqls ON sqls.Owner = o.Owner AND sqls.Object_Name = o.Object_Name
      GROUP BY NVL(o.Owner,'[UNKNOWN]'), NVL(o.Object_Name,'TS='||ts.Name)#{@show_partitions=="1" ? ", o.SubObject_Name" : ""}
      ORDER BY 7 DESC", @instance, @instance]
    @total_blocks = 0                  # Summation der Blockanzahl des Caches
    @objects.each do |o|
      @total_blocks += o.blocks
    end

    render_partial
  end # list_db_cache_content

  def show_using_sqls
    @object_owner = prepare_param :ObjectOwner
    @object_name  = prepare_param :ObjectName
    @instance     = prepare_param_instance

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

    # in Oracle 19.6 Select from gv$SQL ord gv$SQL_Plan shows cardinality of 1 => NESTED LOOP
    @sqls = sql_select_iterator ["
       SELECT /*+ USE_HASH(p s) */ s.Inst_ID, SUBSTR(s.SQL_TEXT,1,100) SQL_Text,
              s.Executions, s.Fetches, TO_DATE(s.First_Load_Time, 'YYYY-MM-DD/HH24:MI:SS') First_load_time,
              s.Parsing_Schema_Name,
              TO_DATE(s.Last_Load_Time, 'YYYY-MM-DD/HH24:MI:SS') last_load_time,
              s.Last_Active_Time,
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
              p.operation, p.options, p.access_predicates, p.Search_Columns, p.Filter_Predicates, p.Cost, p.Cardinality, p.CPU_Cost, p.IO_Cost, p.Bytes, p.Partition_Start, p.Partition_Stop, p.Partition_ID, p.Time
       FROM gV$SQL_Plan p
       JOIN gv$SQL s     ON (    s.SQL_ID          = p.SQL_ID
                             AND s.Plan_Hash_Value = p.Plan_Hash_Value
                             AND s.Inst_ID         = p.Inst_ID
                             AND s.Child_Number    = p.Child_Number
                            )
       WHERE #{wherestr}
       ORDER BY s.Elapsed_Time DESC"].concat whereval
    render_partial
  end

  def list_cursor_memory
    @instance =  prepare_param_instance
    @sid      =  params[:sid].to_i
    @serial_no = params[:serial_no].to_i
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
          Operation, Options, Object_Owner, Object_Name, Object_Type, Optimizer, Other_Tag,
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
      show_popup_message 'This funktion is available only for Oracle 11g and above!'
      return
    end

    if params[:commit] == 'Show invalidations'
      list_result_cache_invalidations
    else
      list_result_cache_content
    end
  end

  def list_result_cache_invalidations
    @dependencies = sql_select_iterator "\
      SELECT d.Inst_ID, d.Status, d.Name, d.Creation_Timestamp, u.UserName, d.Depend_Count, d.SCN Invalidation_SCN, d.Invalidations,
             (SELECT UserName FROM DBA_Users WHERE User_ID = r.Min_User_ID) Min_Creator,
             (SELECT UserName FROM DBA_Users WHERE User_ID = r.Max_User_ID) Max_Creator,
             CASE WHEN r.Creator_Count > 1 THEN '< '||r.Creator_Count||' >' ELSE (SELECT UserName FROM DBA_Users WHERE User_ID = r.Max_User_ID) END Creator,
             r.*
      FROM   gv$Result_Cache_Objects d
      LEFT OUTER JOIN (SELECT dd.Inst_ID, dd.depend_ID, r.Status Result_Status, r.Name Result_Name, r.Namespace Result_Namespace,
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
                       FROM   gV$RESULT_CACHE_DEPENDENCY dd
                       LEFT OUTER JOIN gv$Result_Cache_Objects r ON r.Inst_ID = dd.Inst_ID AND r.ID = dd.Result_ID
                       GROUP BY dd.Inst_ID, dd.depend_ID, r.Status, r.Name, r.Namespace
                      ) r ON r.Inst_ID = d.Inst_ID AND r.Depend_ID = d.ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = d.Creator_UID
      WHERE  d.Type = 'Dependency'
      AND    d.Invalidations > 0
      ORDER BY d.Invalidations DESC"

    render_partial :list_result_cache_invalidations
  end

  def list_result_cache_content
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
                     o.Inst_ID, o.Status, o.Name, RAWTOHEX(o.Name) Hex_Name, o.NameSpace,
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

    render_partial :list_result_cache
  end

  def list_result_cache_single_results
    @instance   = params[:instance]
    @status     = params[:status]
    @name       = params[:name]
    @hex_name   = params[:hex_name]                                             # Name may contain binary 0000..
    @namespace  = params[:namespace]

    @results = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName
      FROM   gv$Result_Cache_Objects o
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      WHERE  Inst_ID        = ?
      AND    Status         = ?
      AND    RAWTOHEX(Name) = ?
      AND    NameSpace      = ?
      AND    Type           = 'Result'
      ", @instance, @status, @hex_name,@namespace]

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
    @id         = prepare_param(:id)
    @status     = params[:status]
    @name       = params[:name]
    @hex_name   = params[:hex_name]                                             # Name may contain binary 0000..
    @namespace  = params[:namespace]

    @dependencies =  sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             o.*,
             u.UserName,
             j.Object_Type
      FROM   (SELECT /*+ NO_MERGE */ d.Inst_ID, d.Depend_ID
              FROM  gv$Result_Cache_Objects r
              JOIN  gV$RESULT_CACHE_DEPENDENCY d ON d.Inst_ID = r.Inst_ID AND d.Result_ID = r.ID
              WHERE r.Inst_ID         = ?
              AND   r.Status          = ?
              AND   RAWTOHEX(r.Name)  = ?
              AND   r.NameSpace       = ?
              GROUP BY d.Inst_ID, d.Depend_ID
             ) d
      JOIN   gv$Result_Cache_Objects o ON o.Inst_ID = d.Inst_ID AND o.ID = d.Depend_ID
      LEFT OUTER JOIN DBA_Users u ON u.User_ID = o.Creator_UID
      LEFT OUTER JOIN DBA_objects j ON j.Object_ID = o.Object_No
      WHERE  o.Type       = 'Dependency'
      ", @instance, @status, @hex_name, @namespace]


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
      format.html {render :html => output }
    end
  end

  # List cache-Entries of object
  def list_db_cache_by_object
    @owner       = params[:owner]
    @object_name = params[:object_name]

    @caches = sql_select_all ["
      WITH Tablespaces AS (SELECT /*+ NO_MERGE MATERIALIZE */ DISTINCT v.TS#, v.Name, t.Block_Size
                           FROM   v$Tablespace v
                           JOIN   DBA_Tablespaces t ON t.Tablespace_Name = v.Name
                          )
      SELECT x.Inst_ID, Owner, Object_Name, SubObject_Name, Object_Type,
             SUM(x.Blocks * ts.Block_Size)/(1024*1024) MB_Total,
             SUM(x.Blocks * ts.Block_Size)/(SELECT Value FROM gv$SGA s WHERE s.Inst_ID = x.Inst_ID AND s.Name = 'Database Buffers')*100 Pct,
             SUM(Blocks) Blocks,
             SUM(Dirty)  Dirty,
             SUM(xcur)   xcur,
             SUM(scur)   scur,
             SUM(cr)     cr,
             SUM(read)   read
      FROM   (
              SELECT o.Owner, o.Object_Name, o.SubObject_Name, o.Object_Type, c.Inst_ID, TS#, COUNT(*) Blocks,
                     SUM(DECODE(c.Dirty, 'Y', 1, 0)) Dirty,
                     SUM(DECODE(c.Status, 'xcur', 1, 0)) xcur,
                     SUM(DECODE(c.Status, 'scur', 1, 0)) scur,
                     SUM(DECODE(c.Status, 'cr', 1, 0)) cr,
                     SUM(DECODE(c.Status, 'read', 1, 0)) read
              FROM   (SELECT /*+ NO_MERGE */ *
                      FROM   (
                              SELECT Owner, Object_Name, SubObject_Name, Object_Type, Data_Object_ID
                              FROM   DBA_Objects
                              WHERE  Owner = ? AND Object_Name = ?
                              UNION ALL   /* Include all indexes of a table if object is a table */
                              SELECT Owner, Object_Name, SubObject_Name, Object_Type, Data_Object_ID
                              FROM   DBA_Objects
                              WHERE (Owner, Object_Name) IN (SELECT Owner, Index_Name FROM DBA_Indexes WHERE Table_Owner = ? AND Table_Name = ?)
                             )
                     ) o
              JOIN   gv$BH c ON c.Objd = o.Data_Object_ID
              GROUP BY c.Inst_ID, TS#, o.Owner, o.Object_Name, o.SubObject_Name, o.Object_Type
             ) x
      JOIN   Tablespaces ts ON ts.TS# = x.TS#
      GROUP BY Inst_ID, Owner, Object_Name, SubObject_Name, Object_Type
      ORDER BY MB_Total DESC
    ", @owner, @object_name, @owner, @object_name]

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

  def show_sql_plan_management
    @profile_count = nil
    @profile_count = sql_select_one "SELECT COUNT(*) FROM DBA_SQL_Profiles" if get_db_version >= '10.1'

    @baseline_count = nil
    @baseline_count = sql_select_one "SELECT COUNT(*) FROM DBA_SQL_Plan_Baselines" if get_db_version >= '11.1'

    @outline_count = sql_select_one "SELECT COUNT(*) FROM DBA_Outlines"

    @translation_count = nil
    @translation_count = sql_select_one "SELECT COUNT(*) FROM DBA_SQL_Translations" if get_db_version >= '12.1'

    @patches_count = nil
    @patches_count = sql_select_one "SELECT COUNT(*) FROM DBA_SQL_Patches" if get_db_version >= '11.1'

    sql_management_config = sql_select_all "SELECT * FROM DBA_SQL_Management_Config"

    column_options = []
    record = {}

    sql_management_config.each do |rec|
      record[rec.parameter_name] = rec.parameter_value

      column_options << {:caption=>rec.parameter_name.gsub('_', ' '),  :data=>proc{|irec| irec[rec.parameter_name]}, :title=>rec.parameter_name}
    end

    @sql_management_config = gen_slickgrid([record], column_options, :caption => "Config data from DBA_SQL_Management_Config", width: :auto)

    render_partial
  end

  # Existierende SQL-Profiles
  def show_profiles
    @force_matching_signature = prepare_param(:force_matching_signature)
    @exact_matching_signature = prepare_param(:exact_matching_signature)
    @sql_profile              = prepare_param(:sql_profile)
    @update_area              = prepare_param(:update_area)

    where_string = ''
    where_values = []
    @caption = "SQL profiles from DBA_SQL_Profiles"
    @single_sql = false                                                         # look for whole DB

    if @force_matching_signature && @exact_matching_signature
      where_string << "WHERE  p.Signature = TO_NUMBER(?) OR  p.Signature = TO_NUMBER(?) "
      where_values << @exact_matching_signature.to_s                            # dont show real numeriv value, not xEy
      where_values << @force_matching_signature.to_s                            # dont show real numeriv value, not xEy
      @single_sql = true
      if @sql_profile
        where_string << " OR p.Name = ?"
        where_values << @sql_profile
      end
      @caption = "<div style=\"background-color: coral;\">SQL-Profiles exists for SQL (from DBA_SQL_Profiles)</div>".html_safe
    end

    @profiles = sql_select_all ["SELECT p.*#{", em.SGA_Usages, awr.AWR_Usages, awr.Min_History_SQL_ID" unless @single_sql}
                                 FROM   DBA_SQL_Profiles p
                                 #{"LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ SQL_Profile, COUNT(*) SGA_Usages
                                                     FROM   gv$SQLArea
                                                     WHERE  SQL_profile IS NOT NULL
                                                     GROUP BY SQL_Profile
                                                    ) em ON em.SQL_Profile = p.Name
                                 LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ SQL_Profile, COUNT(DISTINCT SQL_ID) AWR_Usages, MIN(SQL_ID) Min_History_SQL_ID
                                                    FROM   DBA_Hist_SQLStat
                                                    WHERE  SQL_profile IS NOT NULL
                                                    GROUP BY SQL_Profile
                                                   ) awr ON awr.SQL_Profile = p.Name" unless @single_sql}
                                  #{where_string}
                                 "].concat(where_values)
    render_partial
  end

  def list_sql_profile_sqltext
    @sql = sql_select_one ["SELECT SQL_Text FROM  DBA_SQL_Profiles WHERE Name = ?", params[:profile_name]]
    respond_to do |format|
      format.html {render :html => render_code_mirror(@sql) }
    end

  end

  # Existierende SQL-Plan Baselines
  def show_plan_baselines
    @force_matching_signature = prepare_param(:force_matching_signature)
    @exact_matching_signature = prepare_param(:exact_matching_signature)

    where_string = ''
    where_values = []

    if @force_matching_signature || @exact_matching_signature
      where_string << " WHERE b.Signature IN (?,?)"
      where_values << @force_matching_signature
      where_values << @exact_matching_signature
    end

    if @force_matching_signature && @exact_matching_signature &&
        sql_select_one(["SELECT COUNT(*) FROM DBA_SQL_Plan_Baselines b #{where_string}"].concat(where_values)) == 0
      @baselines = []                                                           # Suppress long running SQL if there is no result
    else
      @baselines = sql_select_all ["SELECT b.*, em.SGA_Usages, em.SQL_ID, em.Inst_ID,
                                           #{ PanoramaConnection.autonomous_database? ? "NULL" : "NVL(so.comp_data_count, 0)" }  comp_data_count
                                    FROM   DBA_SQL_Plan_Baselines b
                                    #{ "\
                                    LEFT OUTER JOIN (SELECT so.Name, so.Signature, COUNT(*) Comp_Data_Count
                                                     FROM   sys.SQLOBJ$ so
                                                     JOIN sys.sqlobj$data sod ON   sod.signature = so.signature
                                                                              AND  sod.category  = so.category
                                                                              AND  sod.obj_type  = so.obj_type
                                                                              AND  sod.plan_id   = so.plan_id
                                                      WHERE so.Obj_Type = 2 /* SQL plan baseline */
                                                      GROUP BY so.Name, so.Signature
                                                    ) so ON so.Name = b.Plan_Name AND so.Signature = b.Signature
                                      " unless PanoramaConnection.autonomous_database?
                                    }
                                    LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ SQL_Plan_Baseline, COUNT(*) SGA_Usages,
                                                              MIN(SQL_ID) SQL_ID,
                                                              MIN(Inst_ID) KEEP (DENSE_RANK FIRST ORDER BY SQL_ID) Inst_ID /* Inst_ID according to MIN(SQL_ID) */
                                                       FROM   gv$SQLArea
                                                       WHERE  SQL_Plan_Baseline IS NOT NULL
                                                       GROUP BY SQL_Plan_Baseline
                                                      ) em ON em.SQL_Plan_Baseline = b.Plan_Name
                                    #{where_string}
                                     "].concat(where_values)
    end
    render_partial
  end

  def list_plan_baseline_hints
    @plan_name = params[:plan_name]
    @signature = params[:signature]

    @baseline_hints = sql_select_all ["SELECT sod.comp_data
                                       FROM   sys.SQLOBJ$ so
                                       JOIN   sys.sqlobj$data sod ON  sod.signature = so.signature
                                                                  AND  sod.category  = so.category
                                                                  AND  sod.obj_type  = so.obj_type
                                                                  AND  sod.plan_id   = so.plan_id
                                       WHERE  so.Name = ? AND so.Signature = ? AND so.Obj_Type = 2 /* SQL plan baseline */
                                     ", @plan_name, @signature]
    render_partial
  end

  def list_plan_baseline_dbms_xplan
    baselines = sql_select_all ["SELECT Plan_Table_Output FROM TABLE(DBMS_XPLAN.display_sql_plan_baseline(?, ?))", params[:sql_handle], params[:plan_name]]
    baseline = ''
    baselines.each do |b|
      baseline << my_html_escape(b.plan_table_output)
      baseline << "<br/>"
    end
    respond_to do |format|
      format.html {render :html => "<pre class='yellow-panel' style='white-space: pre-wrap;'>#{baseline}</pre>".html_safe }
    end
  end

  def list_sql_plan_baseline_sqltext
    @sql = sql_select_one ["SELECT SQL_Text FROM  DBA_SQL_Plan_Baselines WHERE Plan_Name = ?", params[:plan_name]]
    respond_to do |format|
      format.html {render :html => render_code_mirror(@sql) }
    end

  end


  # Existierende stored outlines
  def show_stored_outlines
    @force_matching_signature = prepare_param(:force_matching_signature)
    @exact_matching_signature = prepare_param(:exact_matching_signature)

    where_string = ''
    where_values = []
    @caption = "Stored outlines from DBA_Outlines"
    @single_sql = false

    if @force_matching_signature && @exact_matching_signature
      where_string << "WHERE  Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?)) OR     Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?))"
      where_values << @exact_matching_signature.to_s                            # dont show real numeriv value, not xEy
      where_values << @force_matching_signature.to_s                            # dont show real numeriv value, not xEy

      @caption = "<div style=\"background-color: coral;\">Stored outlines exists for SQL (from DBA_Outlines)</div>".html_safe
      @single_sql = true
    end

    @outlines = sql_select_all ["SELECT *
                                 FROM   DBA_Outlines
                                 #{where_string}"].concat(where_values)

    render_partial
  end

  def show_sql_translations
    @translated_sql_id = params[:translated_sql_id]                             # optional filter condition
    @translated_sql_id = nil if @translated_sql_id == ''

    where_string = ''
    where_values = []

    if @translated_sql_id
      if 0 < sql_select_one(["SELECT COUNT(*) FROM gv$SQLArea WHERE SQL_ID = ? AND RowNum < 2", @translated_sql_id])
        where_string << "WHERE DBMS_LOB.COMPARE(t.Translated_Text, (SELECT SQL_FullText FROM gv$SQLArea WHERE SQL_ID = ? AND RowNum < 2)) = 0"
        where_values << @translated_sql_id
      else
        if 0 < sql_select_one(["SELECT COUNT(*) FROM DBA_Hist_SQLText WHERE DBID = ? AND SQL_ID = ? AND RowNum < 2", get_dbid, @translated_sql_id])
          where_string << "WHERE DBMS_LOB.COMPARE(t.Translated_Text, (SELECT SQL_Text FROM DBA_Hist_SQLText WHERE DBID = ? AND SQL_ID = ? AND RowNum < 2)) = 0"
          where_values << get_dbid
          where_values << @translated_sql_id
        else
          where_string << "WHERE 1=2"    # without hit
          Rails.logger.error('DbaSgaController.show_sql_translations') { "No SQL text found in gv$SQLArea or DBA_Hist_SQLText for SQL-ID='#{@translated_sql_id}'" }
        end
      end
    end

    @translations = sql_select_all ["SELECT t.Owner, t.Profile_Name, SUBSTR(t.SQL_Text, 1,20) SQL_Text, t.SQL_ID, SUBSTR(t.translated_Text, 1,20) Translated_Text, t.Enabled
                                            #{", t.Registration_Time, t.Client_Info, t.Module, t.Action, uu.UserName Parsing_User_Name, us.UserName Parsing_Schema_Name, t.Comments" if get_db_version > '12.1.0.1.0' }
                                            #{", t.Error_Code, t.Error_Source, t.Translation_Method, t.Dictionary_SQL_ID " if get_db_version >= '12.2'}
                                     FROM   DBA_SQL_Translations t
                                     #{"LEFT OUTER JOIN All_Users uu ON uu.User_ID = t.Parsing_User_ID
                                        LEFT OUTER JOIN All_Users us ON uu.User_ID = t.Parsing_Schema_ID" if get_db_version > '12.1.0.1.0' }
                                     #{where_string}
                                    "].concat(where_values)
    render_partial
  end

  def list_sql_translation_sql_text
    @sql_text = sql_select_one ["SELECT SQL_Text FROM DBA_SQL_Translations WHERE Owner = ? AND Profile_Name = ? AND SQL_ID = ?", params[:owner], params[:profile_name], params[:sql_id]]
    respond_to do |format|
      format.html {render :html => render_code_mirror(@sql_text) }
    end
  end

  def list_sql_translation_translated_text
    @sql_text = sql_select_one ["SELECT Translated_Text FROM DBA_SQL_Translations WHERE Owner = ? AND Profile_Name = ? AND SQL_ID = ?", params[:owner], params[:profile_name], params[:sql_id]]
    respond_to do |format|
      format.html {render :html => render_code_mirror(@sql_text) }
    end
  end

  def show_sql_patches
    @exact_signature = params[:exact_signature]
    @force_signature = params[:force_signature]

    where_stmt = ''
    where_values = []

    if @exact_signature && @force_signature
      where_stmt = "WHERE (p.Force_Matching = 'YES' AND p.Signature = ?) OR (p.Force_Matching = 'NO' AND p.Signature = ?)"
      where_values << @force_signature
      where_values << @exact_signature
    end

    begin
      sql_column_list = "s.Min_Inst_ID, NVL(s.Instance_Count, 0) Instance_Count, s.Min_SQL_ID, NVL(s.SQL_ID_Count, 0) SQL_ID_Count"
      sql_join        = "LEFT OUTER JOIN (SELECT /*+ NO_MERGE */          SQL_Patch,
                                                 MIN(Inst_ID)             Min_Inst_ID,
                                                 COUNT(DISTINCT Inst_ID)  Instance_Count,
                                                 MIN(SQL_ID)              Min_SQL_ID,
                                                 COUNT(DISTINCT SQL_ID)   SQL_ID_Count
                                          FROM   gv$SQL
                                          WHERE  SQL_Patch IS NOT NULL
                                          GROUP BY SQL_Patch
                                         ) s ON s.SQL_Patch = p.Name"

      @sql_patches = sql_select_all ["SELECT p.*, TO_CHAR(p.Signature) Char_Signature, sod.comp_data, #{sql_column_list}
                                      FROM DBA_SQL_Patches p
                                      #{sql_join}
                                      JOIN sys.sqlobj$ so ON so.Name = p.Name AND so.Signature = p.Signature AND so.Category = p.Category AND so.Obj_Type = 3 /* SQL patch */
                                      JOIN sys.sqlobj$data sod ON sod.signature = so.signature
                                                      and     sod.category = so.category
                                                      and     sod.obj_type = so.obj_type
                                                      and     sod.plan_id = so.plan_id
                                      #{where_stmt}"].concat(where_values)
    rescue Exception                                                            # workaround for autonomous cloud service without access on sys-tables
      @sql_patches = sql_select_all ["SELECT p.*, TO_CHAR(p.Signature) Char_Signature, 'No access allowed on sys.sqlobj$ and sys.sqlobj$data !' comp_data, #{sql_column_list}
                                      FROM DBA_SQL_Patches p
                                      #{sql_join}
                                      #{where_stmt}"].concat(where_values)
    end
    render_partial
  end

  def list_sql_patch_sql_text
    @sql_text = sql_select_one ["SELECT SQL_Text FROM DBA_SQL_Patches WHERE Category = ? AND TO_CHAR(Signature) = ?", params[:category], params[:signature]]
    respond_to do |format|
      format.html {render :html => render_code_mirror(@sql_text) }
    end
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

  def generate_sql_translation
    @sql_id              = params[:sql_id]
    user_name            = params[:user_name]

    if params[:fixed_user].nil? || params[:fixed_user] == ''
      @user_data = sql_select_all ["SELECT u.UserName
                                   FROM   (SELECT DISTINCT User_ID
                                           FROM   gv$Active_Session_History
                                           WHERE  SQL_ID = ?
                                          ) a
                                   JOIN   All_Users u ON u.User_ID = a.User_ID
                                  ", @sql_id]

      user_name = @user_data[0].username if @user_data.count == 1                 # Switch username to the real session owner
      if @user_data.count > 1
        render_partial :select_user_for_generate_sql_translation
        return
      end
    end

    db_trigger_name     = 'SYS.' + "Panorama_Transl_#{user_name}"[0, 30]
    profile_name        = "Panorama_Transl_#{user_name}".upcase[0, 30]

    sql_text = sql_select_one ["SELECT SQL_FullText FROM gv$SQLArea WHERE SQL_ID = ?", @sql_id]
    sql_text = sql_select_one ["SELECT SQL_Text FROM DBA_Hist_SQLText WHERE DBID = ? AND SQL_ID = ?", get_dbid, @sql_id] if sql_text.nil?

    profile_exists = 0 < sql_select_one(["SELECT COUNT(*) FROM DBA_SQL_Translations WHERE Owner = ? AND Profile_Name = ? ", user_name, profile_name])

    result = "
-- Script for establishing SQL translation for SQL-ID='#{@sql_id}' based on SQL translation framework ( https://docs.oracle.com/database/121/DRDAA/sql_transl_arch.htm#DRDAA131 )
-- Generated by Panorama at #{Time.now}
-- Executing this script allows you to change the complete syntax of this SQL. Only result structure and used bind variables must remain consistent.
-- This allows you to transparently fix each problem caused by the semantic of this SQL without any change of the calling application.
-- Existing translations for the resulting SQLs are shown by Panorama in SQL-details view.
-- All existing translations are listed in Panorama via menu 'SGA/PGA-details' / 'SQL plan management' / 'SQL translations'

-- Attributes that must be adjusted by you in this script:
--   - Name of the user that is really executing the SQL if this is different from current choosen user '#{user_name}'
--   - Translated SQL text, currently initialized with the text of the original SQL

-- To activate the translation you must reconnect your session to make the LOGON-trigger working (restart application or reset session pool)

-- ############# Following acitivities should be sequentially executed in this order to establish translation #############

-- 1. ####### Execute as user SYS to establish translation:

GRANT CREATE SQL TRANSLATION PROFILE TO #{user_name};

GRANT ALTER SESSION TO #{user_name};


-- 2. ####### Execute as user #{user_name} to establish translation:

#{ "-- Following sequence for profile creation commented out because profile already exists for user #{user_name}
-- " if profile_exists}EXEC DBMS_SQL_TRANSLATOR.CREATE_PROFILE('#{profile_name}');

BEGIN
DBMS_SQL_TRANSLATOR.REGISTER_SQL_TRANSLATION('#{profile_name}',
'#{sql_escape(sql_text)}',
-- ####### Adjust the following SQL text as translation target on your needs
'#{sql_escape(sql_text)}',
TRUE);
END;
/


-- 3. ####### Execute as user SYS to establish translation:

CREATE TRIGGER #{db_trigger_name} AFTER LOGON ON DATABASE
BEGIN
  -- created by SQL translation script generated by Panorama to allow translation of SQL with SQL-ID='#{@sql_id}'
  IF USER = '#{user_name}' THEN
    EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA=#{user_name}';
    EXECUTE IMMEDIATE 'ALTER SESSION SET SQL_TRANSLATION_PROFILE=#{profile_name}';
    EXECUTE IMMEDIATE 'ALTER SESSION SET EVENTS =''10601 trace name context forever, level 32''';
  END IF;
END;
/

-- ############# Following acitivities should be sequentially executed in this order to remove translation if not needed anymore #############

-- 1. ####### Execute as user SYS to remove translation if not needed anymore:

DROP TRIGGER #{db_trigger_name};

-- 2. ####### Execute as user #{user_name} to remove translation if not needed anymore:

BEGIN
DBMS_SQL_TRANSLATOR.DEREGISTER_SQL_TRANSLATION('#{profile_name}',
'#{sql_escape(sql_text)}'
);
END;
/

-- Drop profile only if no more translations are registered to the profile (see DBA_SQL_Translations)
--EXEC DBMS_SQL_TRANSLATOR.DROP_PROFILE('#{profile_name}');


-- ############ Remarks:
-- To activate the translation you must usually reconnect your session to make the LOGON-trigger working.
-- There is a solution to set the needed event in an already running session like:
-- EXEC DBMS_SYSTEM.set_ev(<sid>, <serial#>, 10601, 32, '');
-- but I did not found a solution for setting SQL_TRANSLATION_PROFILE=#{profile_name} in a running session


"

    respond_to do |format|
      format.html {render :html => render_code_mirror(result) }
    end
  end

  def generate_sql_patch
    @sql_id              = params[:sql_id]

    patch_name     = "Panorama-Patch #{@sql_id}"

    sql_text = sql_select_one ["SELECT SQL_FullText FROM gv$SQLArea WHERE SQL_ID = ?", @sql_id]
    if sql_text.nil?
      if PackLicense.none_licensed?
        raise "No SQL text found for SQL-ID='#{@sql_id}' in gv$SQLArea"
      else
        sql_text = sql_select_one ["SELECT SQL_Text FROM DBA_Hist_SQLText WHERE DBID = ? AND SQL_ID = ?", get_dbid, @sql_id]
        raise "No SQL text found for SQL-ID='#{@sql_id}' in gv$SQLArea or DBA_Hist_SQLText" if sql_text.nil?
      end
    end

    existing_patch_for_sql = sql_select_one ["SELECT Name
                                              FROM   DBA_SQL_Patches p
                                              CROSS JOIN (SELECT /*+ NO_MERGE */ SQL_Text
                                                          FROM   (
                                                                  SELECT SQL_FullText SQL_Text FROM gv$SQLArea WHERE SQL_ID = ?
                                                                  #{"UNION ALL
                                                                  SELECT SQL_Text FROM DBA_Hist_SQLText WHERE DBID = ? AND SQL_ID = ?" if !PackLicense.none_licensed?
                                                                  }
                                                                 )
                                                          WHERE  RowNum < 2
                                                         ) s
                                              WHERE  DBMS_LOB.Compare(p.SQL_Text, s.SQL_Text) = 0
                                             ", @sql_id].concat(!PackLicense.none_licensed? ? [get_dbid, @sql_id] : [])

    result = "
-- Script for establishing SQL patch for SQL-ID='#{@sql_id}'
-- Generated by Panorama at #{Time.now}
-- Executing this script allows you to add optimizer hints that are used for execution of this SQL.
-- This allows you to transparently influence execution plan without any change of the calling application.
-- Existing SQL-patches for SQLs are shown by Panorama in SQL-details view.
-- All existing SQL-patches are listed in Panorama via menu 'SGA/PGA-details' / 'SQL plan management' / 'SQL patches'

-- Attributes that must be adjusted by you in this script for parameters:
--   - 'hint_text'   Place your optimizer hints here.
--                   Be aware that query block names and table-aliases must be used in optimizer hints
--                   with same values as they appear in columns QBLOCK_NAME and OBJECT_ALIAS of v$SQL_PLAN!
--                   Panorama shows query block name and alias in execution plan view by mouse over hint on column \"Object name\".
--                   Example: \"FULL(@SEL$E029B2FF tab@SEL$2)\" where \"tab\" ist the table alias used in SQL-statement
--   - 'decription'  describe purpose of SQL-patch

-- ############# To establish SQL patch execute this as SYSDBA #############
-- on Pluggable database execute it connected to PDB, not CDB

#{ "-- Drop already existing SQL-Patch for this SQL before applying new patch
EXEC DBMS_SQLDiag.Drop_SQL_Patch('#{existing_patch_for_sql}');
" if !existing_patch_for_sql.nil?}
#{
  get_db_version >= '12.2' ?
      "
DECLARE
  patch_name VARCHAR2(32767);
BEGIN
  patch_name := sys.DBMS_SQLDiag.create_SQL_patch(" :
      "
BEGIN
  sys.DBMS_SQLDiag_Internal.i_create_patch("
}
    sql_text    => '#{sql_escape(sql_text)}',
    hint_text   => '< my personal hint>',
    name        => '#{patch_name}',
    description => 'My personal description for patch'
  );
END;
/


-- ############# To remove the SQL-patch if not needed anymore execute this as SYSDBA #############
-- EXEC DBMS_SQLDiag.Drop_SQL_Patch('#{patch_name}');
"

    respond_to do |format|
      format.html {render :html => render_code_mirror(result) }
    end
  end

  def list_resize_operations_historic
    save_session_time_selection
    @instance     = prepare_param_instance
    @dbid         = prepare_param_dbid
    @time_groupby = params[:time_groupby].to_sym if params[:time_groupby]
    @update_area = get_unique_area_id


    where_string = ''
    where_values = []

    unless @instance.nil?
      where_string << " AND Instance_Number = ?"
      where_values << @instance
    end

    @min_snap_id, @max_snap_id = get_min_max_snap_ids(@time_selection_start, @time_selection_end, @dbid, raise_if_not_found: true)

    case @time_groupby.to_sym
    when :second then group_by_value = "o.Start_Time"
    when :minute then group_by_value = "TRUNC(o.Start_Time, 'MI')"
    when :hour   then group_by_value = "TRUNC(o.Start_Time, 'HH24')"
    when :day    then group_by_value = "TRUNC(o.Start_Time)"
    when :week   then group_by_value = "TRUNC(o.Start_Time, 'WW')"
    else
      raise "Unsupported value for parameter :groupby (#{@time_groupby})"
    end


    # In 18.3 this SQL leads to error if not restricted to instance:
    # ORA-12801: Fehler in parallelem Abfrage-Server P000 angezeigt
    # ORA-01006: Bind-Variable nicht vorhanden
    result= sql_select_iterator ["
      SELECT #{group_by_value} Group_Value, o.Component, o.Oper_Type, o.Parameter,
             MIN(o.Start_Time)                                Min_Start_Time,
             MAX(o.End_Time)                                  Max_End_Time,
             SUM((o.End_Time - o.Start_Time)*86400)           Duration_Secs,
             SUM(o.Target_Size - o.Initial_Size)/(1024*1024)  Change_MBytes_Target,
             SUM(o.Final_Size - o.Initial_Size)/(1024*1024)   Change_MBytes_Real,
             (MAX(o.Final_Size) KEEP (DENSE_RANK LAST ORDER BY Start_Time))/(1024*1024) Final_Size_MB,
             COUNT(*)                                         Operations_Count,
             SUM(DECODE(o.Status, 'INACTIVE', 1, 0))          Status_Inactive_Count,
             SUM(DECODE(o.Status, 'PENDING', 1, 0))           Status_Pending_Count,
             SUM(DECODE(o.Status, 'COMPLETE', 1, 0))          Status_Complete_Count,
             SUM(DECODE(o.Status, 'CANCELLED', 1, 0))         Status_Cancelled_Count,
             SUM(DECODE(o.Status, 'ERROR', 1, 0))             Status_Error_Count
      FROM   DBA_Hist_Memory_Resize_Ops o
      WHERE  o.Start_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    o.End_Time   <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_string}
      AND    o.DBID = ?
      AND    o.Snap_ID BETWEEN ? AND ?
      GROUP BY #{group_by_value}, o.Component, o.Oper_Type, o.Parameter
      ORDER BY #{group_by_value}, o.Component, o.Oper_Type, o.Parameter
    ", @time_selection_start, @time_selection_end, @dbid, @min_snap_id, @max_snap_id].concat(where_values)

    result_hash = {}
    pivot_column_tags = {}
    resulting_sizes = {}
    @pivot_columns = []
    result.each do |r|
      column_key = "#{r.component}_#{r.parameter}_#{r.oper_type}"

      unless pivot_column_tags.has_key?(column_key)
        pivot_column_tags[column_key] = 1
        @pivot_columns << {caption:     "#{r.component} #{r.oper_type} resized MB",
                           sort_key:    "#{r.component} #{r.oper_type}",
                           data:        proc{|rec| historic_resize_link_ops(@update_area, rec, fn((rec["#{column_key}_real"] ? rec["#{column_key}_real"] : 0), 2), rec["#{column_key}_real"], r.component, r.oper_type)},
                           title:       "Sum MBytes of real size changes for resize operations in considered period on:\nComponent = #{r.component}\nParameter = #{r.parameter}\nOperation type = #{r.oper_type}",
                           data_title:  proc{|rec| "%t\nNumber of MBytes targeted for operation = #{fn(rec["#{column_key}_target"], 2)}"},
                           align:       "right"
        }

      end

      resulting_sizes[r.component] = r.final_size_mb

      unless result_hash.has_key?(r.group_value)                                # initiate new record
        result_hash[r.group_value] = {
            min_start_time:           r.min_start_time,
            max_end_time:             r.max_end_time,
            duration_secs:            0,
            operations_count:         0
        }
      end

      record = result_hash[r.group_value]                                       # get shortcut for existing record

      record[:min_start_time]   = r.min_start_time        if r.min_start_time < record[:min_start_time]
      record[:max_end_time]     = r.max_end_time          if r.max_end_time   > record[:max_end_time]
      record[:duration_secs]    += r.duration_secs
      record[:operations_count] += r.operations_count

      record["#{column_key}_target"] = 0 unless record.has_key?("#{column_key}_target")
      record["#{column_key}_target"] += r.change_mbytes_target

      record["#{column_key}_real"] = 0 unless record.has_key?("#{column_key}_real")
      record["#{column_key}_real"] += r.change_mbytes_target

      resulting_sizes.each do |key, value|                                      # Ensure that resulting sizes occur on every record starting with first occurrence
        record["#{key}_resulting_size"] =  value
      end

    end


    resulting_sizes.each do |key, value|                                      # add column definition for all resulting sizes
      @pivot_columns << {caption:     "#{key} final size MB",
                         sort_key:    "#{key} x",
                         data:        proc{|rec| historic_resize_link_ops(@update_area, rec, fn(rec["#{key}_resulting_size"], 2), rec["#{key}_resulting_size"], key, nil)       },
                         title:       "Final size of component at the end of considered period on:\nComponent = #{key}",
                         align:       "right"
      }
    end
    @pivot_columns.sort! {|a, b| a[:sort_key] <=> b[:sort_key]}

    @result = []
    result_hash.each do |key, value|
      value.extend SelectHashHelper
      @result << value
    end

    # Fill missing values from begin until first ocurrence of value, resulting_sizes has values of last record
    @result.reverse.each do |r|

    end

    render_partial
  end

  def list_resize_operations_historic_single_record
    @time_selection_start = params[:time_selection_start]
    @time_selection_end   = params[:time_selection_end]
    @instance     = prepare_param_instance
    @dbid         = prepare_param_dbid
    @component    = params[:component]
    @component    = nil if @component == ''

    @oper_type    = params[:oper_type]
    @oper_type    = nil if @oper_type == ''

    where_string = ''
    where_values = []

    unless @instance.nil?
      where_string << " AND Instance_Number = ?"
      where_values << @instance
    end

    unless @component.nil?
      where_string << " AND Component = ?"
      where_values << @component
    end

    unless @oper_type.nil?
      where_string << " AND oper_type = ?"
      where_values << @oper_type
    end

    @min_snap_id, @max_snap_id = get_min_max_snap_ids(@time_selection_start, @time_selection_end, @dbid, raise_if_not_found: true)

    @result = sql_select_iterator ["
      SELECT *
      FROM   DBA_Hist_Memory_Resize_Ops
      WHERE  DBID = ?
      AND    Snap_ID BETWEEN ? AND ?
      AND    Start_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    End_Time   <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_string}
      ORDER BY Start_Time
    ", @dbid, @min_snap_id, @max_snap_id, @time_selection_start, @time_selection_end].concat(where_values)

    render_partial
  end

  def expand_sql_text
    sql_id = params[:sql_id]

    original_sql = sql_select_one ["SELECT SQL_FullText FROM gv$SQLArea WHERE SQL_ID = ? AND RowNum < 2", sql_id]

    expanded_sql = sql_select_one ["\
      WITH
        FUNCTION Expand(p_Org_SQL CLOB) RETURN CLOB
        IS
        v_Expanded_SQL CLOB;
        BEGIN
          DBMS_UTILITY.expand_sql_text(input_sql_text => p_Org_SQL, output_sql_text => v_Expanded_SQL);
          RETURN v_Expanded_SQL;
        END;
      SELECT Expand(?) FROM DUAL", original_sql]

    formatted_sql = format_sql(expanded_sql, params[:window_width])

    formatted_sql
        .remove!('"')                                                           # remove all " from result
        .gsub!(/A[0123456789].*/){|s| s.downcase }                              # switch table aliases (Ann) to downcase

    respond_to do |format|
      format.html {render :html => render_code_mirror(formatted_sql) }
    end


  end

  def list_historic_sga_components
    @instance = prepare_param_instance
    save_session_time_selection  # werte in session puffern
    pool_details  = prepare_param(:pool_details) == '1'
    @con_id       = prepare_param :con_id

    where_string = ''
    where_values = []
    if @instance
      where_string << " AND s.Instance_Number = ?"
      where_values << @instance
    end
    if @con_id
      where_string << " AND s.Con_ID = ?"
      where_values << @con_id
    end

    sgastat = sql_select_iterator ["SELECT ROUND(ss.Begin_Interval_Time, 'MI') Rounded_Begin_Interval_Time,
                                           #{pool_details ? "DECODE(s.Pool, NULL, '', s.Pool||' / ')||s.Name" : "NVL(s.Pool, s.Name) "} Pool,
                                           s.Bytes/(1024*1024) MBytes
                                    FROM   DBA_Hist_SGAStat s
                                    JOIN   DBA_hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                                    WHERE  ss.Begin_Interval_Time  >= TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_start)}')
                                    AND    ss.End_Interval_Time    <= TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_end)}')
                                    #{where_string}
                                    ORDER BY 1
                                    ", @time_selection_start, @time_selection_end].concat(where_values)
    pools = {}
    result_hash ={}                                                             # Rounded_Begin_Interval_Time as key
    sgastat.each do |s|
      unless result_hash.has_key?(s.rounded_begin_interval_time)
        result_hash[s.rounded_begin_interval_time] = {
          rounded_begin_interval_time: s.rounded_begin_interval_time,
          total_mb: 0
        }.extend(SelectHashHelper)
      end

      target_hash = result_hash[s.rounded_begin_interval_time]
      target_hash[:total_mb] += s.mbytes unless s.mbytes.nil?
      unless target_hash.has_key?(s.pool)
        target_hash[s.pool] = 0
      end
      target_hash[s.pool] += s.mbytes unless s.mbytes.nil?

      pools[s.pool] = 0 unless pools.has_key?(s.pool)
      pools[s.pool] += s.mbytes unless s.mbytes.nil?
    end
    @sga_stats = result_hash.map{|key, value| value}
    @pools = pools.sort_by {|key,value| value}.map{|x| x[0]}    # pool-names sorted by MBytes
    render_partial
  end
end
