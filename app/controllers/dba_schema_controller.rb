# encoding: utf-8
class DbaSchemaController < ApplicationController
  # Einstieg in Seite (Menü-Action)
  def show_object_size
    @tablespaces = sql_select_all("\
      SELECT '[Alle]' Name FROM DUAL UNION ALL                  
      SELECT /* NOA-Tools Ramm */                               
        TABLESPACE_NAME Name                                    
      FROM DBA_TableSpaces                                      
      ORDER BY 1 ");
    @schemas = sql_select_all("\
      SELECT '[Alle]' Name FROM DUAL UNION ALL                  
      SELECT /* NOA-Tools Ramm */                               
        UserName Name                                           
      FROM DBA_Users
      ORDER BY 1 ");
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba_schema/show_object_size" }');"}
    end
  end
  
  # Anlistung der Objekte
  def list_objects
    @tablespace_name = params[:tablespace][:name]
    @schema_name     = params[:schema][:name]
    filter           = params[:filter]
    if params[:showPartitions] == "1"
       groupBy = "Owner, Segment_Name, Tablespace_Name, Segment_Type, Partition_Name"
       partCol = "Partition_Name"
    else
       groupBy = "Owner, Segment_Name, Tablespace_Name, Segment_Type"
       partCol = "DECODE(Count(*),1,NULL,Count(*))"
    end

    where_string = ""
    where_values = []

    if @tablespace_name != '[Alle]'
      where_string << " AND s.Tablespace_Name=?"
      where_values << @tablespace_name
    end

    if @schema_name != '[Alle]'
      where_string << " AND s.Owner=?"
      where_values << @schema_name
    end

    if filter
      where_string << " AND UPPER(s.Segment_Name) LIKE UPPER('%'||?||'%')"
      where_values << filter
    end

    @objects = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
        CASE WHEN Segment_Name LIKE 'SYS_LOB%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 8, 10)) )||')'
             WHEN Segment_Name LIKE 'SYS_IL%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 7, 10)) )||')'
             WHEN Segment_Name LIKE 'SYS_IOT_OVER%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 14, 10)) )||')'
        ELSE Segment_Name
        END Segment_Name_Qual,
        Segment_Name,
        x.*
      FROM (
      SELECT
        Segment_Name,
        Tablespace_Name,
        "+partCol+" PARTITION_NAME,                             
        SEGMENT_TYPE,                                           
        Owner,                                                  
        SUM(EXTENTS)                    Used_Ext,               
        SUM(bytes)/(1024*1024)          MBytes,
        SUM(INITIAL_EXTENT)/1024        Init_Ext,               
        SUM(Num_Rows)                   Num_Rows,               
        AVG(Avg_Row_Len)                Avg_RowLen,
        AVG(100-(((Avg_Row_Len)*Num_Rows*100)/Bytes)) Percent_Free,
        AVG(100-(((Avg_Row_Len)*Num_Rows*100)/Bytes))*SUM(bytes)/(100*1024*1024) MBytes_Free_avg_row_len,
        SUM(Empty_Blocks)               Empty_Blocks,
        AVG(Avg_Space)                  Avg_Space,
        MIN(Last_Analyzed)              Last_Analyzed           
      FROM (                                                    
        SELECT s.Segment_Name,                                  
               s.Partition_Name,                                
               s.Segment_Type,                                  
               s.Tablespace_Name,
               s.Owner,                                         
               s.Extents,                                       
               s.Bytes,                                         
               s.Initial_Extent,                                
               DECODE(s.Segment_Type,                           
                 'TABLE',              t.Num_Rows,
                 'TABLE PARTITION',    tp.Num_Rows,
                 'TABLE SUBPARTITION', tsp.Num_Rows,
                 'INDEX',              i.Num_Rows,
                 'INDEX PARTITION',    ip.Num_Rows,
                 'INDEX SUBPARTITION', isp.Num_Rows,
               NULL) num_rows,
               CASE WHEN s.Segment_Type = 'TABLE'              THEN t.Avg_Row_Len
                    WHEN s.Segment_Type = 'TABLE PARTITION'    THEN tp.Avg_Row_Len
                    WHEN s.Segment_Type = 'TABLE SUBPARTITION' THEN tsp.Avg_Row_Len
                    WHEN s.Segment_Type IN ('INDEX', 'INDEX PARTITION', 'INDEX_SUBPARTITION') AND i.Index_Type = 'NORMAL' THEN
                         (SELECT SUM(tc.Avg_Col_Len) + 10 /* Groesse RowID */
                          FROM   DBA_Ind_Columns ic
                          JOIN   DBA_Tab_Columns tc ON (    tc.Owner       = ic.Table_Owner
                                                        AND tc.Table_Name  = ic.Table_Name
                                                        AND tc.Column_Name = ic.Column_Name
                                                       )
                          WHERE ic.Index_Owner = s.Owner
                          AND   ic.Index_Name  = s.Segment_Name
                         )
                    WHEN s.Segment_Type = 'INDEX' AND i.Index_Type =  'IOT - TOP' THEN
                         (it.Avg_Row_Len + 10 /* Groesse RowID */ ) * 1.3 /* pauschaler Aufschlag fuer B-Baum */
                    WHEN s.Segment_Type = 'INDEX PARTITION' AND i.Index_Type =  'IOT - TOP' THEN
                         (it.Avg_Row_Len + 10 /* Groesse RowID */ ) * 1.3 /* pauschaler Aufschlag fuer B-Baum */
               END avg_row_len,
               DECODE(s.Segment_Type,
                 'TABLE',              t.Empty_blocks,
                 'TABLE PARTITION',    tp.Empty_Blocks,
                 'TABLE SUBPARTITION', tsp.Empty_Blocks,
               NULL) empty_blocks,
               DECODE(s.Segment_Type,
                 'TABLE',              t.Avg_Space,
                 'TABLE PARTITION',    tp.Avg_Space,
                 'TABLE SUBPARTITION', tsp.Avg_Space,
               NULL) Avg_Space,
               DECODE(s.Segment_Type,                           
                 'TABLE',              t.Last_analyzed,
                 'TABLE PARTITION',    tp.Last_analyzed,
                 'TABLE SUBPARTITION', tsp.Last_analyzed,
                 'INDEX',              i.Last_analyzed,
                 'INDEX PARTITION',    ip.Last_analyzed,
                 'INDEX SUBPARTITION', isp.Last_analyzed,
               NULL) Last_Analyzed
        FROM DBA_SEGMENTS s
        LEFT OUTER JOIN DBA_Tables t              ON t.Owner         = s.Owner       AND t.Table_Name   = s.segment_name
        LEFT OUTER JOIN DBA_Tab_Partitions tp     ON tp.Table_Owner  = s.Owner       AND tp.Table_Name  = s.segment_name AND tp.Partition_Name     = s.Partition_Name
        LEFT OUTER JOIN DBA_Tab_SubPartitions tsp ON tsp.Table_Owner = s.Owner       AND tsp.Table_Name = s.segment_name AND tsp.SubPartition_Name = s.Partition_Name
        LEFT OUTER JOIN DBA_indexes i             ON i.Owner         = s.Owner       AND i.Index_Name   = s.segment_name
        LEFT OUTER JOIN DBA_Ind_Partitions ip     ON ip.Index_Owner  = s.Owner       AND ip.Index_Name  = s.segment_name AND ip.Partition_Name     = s.Partition_Name
        LEFT OUTER JOIN DBA_Ind_SubPartitions isp ON isp.Index_Owner = s.Owner       AND isp.Index_Name = s.segment_name AND isp.SubPartition_Name = s.Partition_Name
        LEFT OUTER JOIN DBA_Tables it             ON it.Owner        = i.Table_Owner AND it.Table_Name  = i.Table_Name
        WHERE s.SEGMENT_TYPE<>'CACHE'
        #{where_string}
        )                                                       
      GROUP BY #{groupBy}
      ) x
      ORDER BY x.Segment_Name, x.Tablespace_Name, x.Owner"
      ].concat(where_values)

    respond_to do |format|
      format.js {render :js => "$('#objects').html('#{j render_to_string :partial=>"list_objects" }');"}
    end
  end # objekte_nach_groesse

  def list_table_description
    @owner        = params[:owner]
    @segment_name = params[:segment_name]

    objects = sql_select_all ["SELECT * FROM DBA_Objects WHERE Owner=? AND Object_Name=?", @owner, @segment_name]
    raise "Object #{@owner}.#{@segment_name} does not exist in database" if objects.count == 0
    object = objects[0]

    @table_type = "table"
    @table_type = "materialized view" if objects.count == 2 && (objects[0].object_type == "MATERIALIZED VIEW" || objects[1].object_type == "MATERIALIZED VIEW")

    # Ermitteln der zu dem Objekt gehörenden Table
    case object.object_type
      when "TABLE", "TABLE PARTITION", "TABLE SUBPARTITION", "MATERIALIZED VIEW"
        if @segment_name[0,12] == "SYS_IOT_OVER"
          res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @segment_name[13,10]]
          raise "Segment #{@owner}.#{@segment_name} is not known table type" unless res
          @owner      = res.table_owner
          @table_name = res.table_name
        else
          @table_name = @segment_name
        end
      when "INDEX", "INDEX PARTITION", "INDEX SUBPARTITION"
        if @segment_name[0,6] == "SYS_IL"
          res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @segment_name[6,10]]
        else
          res = sql_select_first_row ["SELECT Table_Owner, Table_Name FROM DBA_Indexes WHERE Owner=? AND Index_Name=?", @owner, @segment_name]
        end
        raise "Segment #{@owner}.#{@segment_name} is not known index type" unless res
        @owner      = res.table_owner
        @table_name = res.table_name
      when "LOB"
        res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @segment_name[7,10]]
        @owner      = res.table_owner
        @table_name = res.table_name
      when "SEQUENCE"
        @seqs = sql_select_all ["SELECT * FROM DBA_Sequences WHERE Sequence_Owner = ? AND Sequence_Name = ?", @owner, @segment_name]
        render_partial "list_sequence_description"
        return
      else
        raise "Segment #{@owner}.#{@segment_name} is of unsupported type #{object.object_type}"
    end

    @attribs = sql_select_all ["SELECT t.*, o.Created, o.Last_DDL_Time
                                FROM DBA_Tables t
                                JOIN DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name AND o.Object_Type = 'TABLE'
                                WHERE t.Owner = ? AND t.Table_Name = ?
                               ", @owner, @table_name]

    @comment = sql_select_one ["SELECT Comments FROM DBA_Tab_Comments WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

    @columns = sql_select_all ["\
                 SELECT /*+ Panorama Ramm */
                       c.*, co.Comments,
                       NVL(c.Data_Precision, c.Char_Length)||CASE WHEN c.Char_Used='B' THEN ' Bytes' WHEN c.Char_Used='C' THEN ' Chars' ELSE '' END Precision
                FROM   DBA_Tab_Columns c
                JOIN   DBA_Col_Comments co ON co.Owner = c.Owner AND co.Table_Name = c.Table_Name AND co.Column_Name = c.Column_Name
                WHERE  c.Owner = ? AND c.Table_Name = ?
                ORDER BY c.Column_ID
               ", @owner, @table_name]

    if @attribs[0].partitioned == 'YES'
      @partition_count = sql_select_one ["SELECT COUNT(*) FROM DBA_Tab_Partitions WHERE  Table_Owner = ? AND Table_Name = ?", @owner, @table_name]
    else
      @partition_count = 0
    end

    @size_mb = sql_select_one ["SELECT /*+ Panorama Ramm */ SUM(Bytes)/(1024*1024) FROM DBA_Segments WHERE Owner = ? AND Segment_Name = ?", @owner, @table_name]

    @indexes = sql_select_all ["\
                 SELECT /*+ Panorama Ramm */ i.*, p.Partition_Number, sp.SubPartition_Number, Partition_TS_Name, SubPartition_TS_Name,
                        Partition_Status, SubPartition_Status, Partition_Pct_Free, SubPartition_Pct_Free,
                        Partition_Ini_Trans, SubPartition_Ini_Trans, Partition_Max_Trans, SubPartition_Max_Trans,
                        (SELECT SUM(Bytes)/(1024*1024)
                         FROM   DBA_Segments s
                         WHERE  s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
                        ) Size_MB,
                        DECODE(bitand(io.flags, 65536), 0, 'NO', 'YES') Monitoring,
                        DECODE(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                        ou.start_monitoring, ou.end_monitoring,
                        do.Created, do.Last_DDL_Time
                 FROM   DBA_Indexes i
                 JOIN   sys.user$   u  ON u.Name  = i.owner
                 JOIN   sys.Obj$    o  ON o.Owner# = u.User# AND o.Name = i.Index_Name
                 JOIN   sys.Ind$    io ON io.Obj# = o.Obj#
                 LEFT OUTER JOIN DBA_Objects do ON do.Owner = i.Owner AND do.Object_Name = i.Index_Name AND do.Object_Type = 'INDEX'
                 LEFT OUTER JOIN sys.object_usage ou ON ou.Obj# = o.Obj#
                 LEFT OUTER JOIN (SELECT ii.Index_Name, COUNT(*) Partition_Number,
                                  CASE WHEN COUNT(DISTINCT(ip.Tablespace_Name)) = 1 THEN MIN(ip.Tablespace_Name) ELSE NULL  END Partition_TS_Name,
                                  CASE WHEN COUNT(DISTINCT(ip.Status))          = 1 THEN MIN(ip.Status)          ELSE 'N/A' END Partition_Status,
                                  CASE WHEN COUNT(DISTINCT(ip.PCT_Free))        = 1 THEN MIN(ip.PCT_Free)        ELSE NULL  END Partition_PCT_Free,
                                  CASE WHEN COUNT(DISTINCT(ip.INI_Trans))       = 1 THEN MIN(ip.INI_Trans)       ELSE NULL  END Partition_INI_Trans,
                                  CASE WHEN COUNT(DISTINCT(ip.MAX_Trans))       = 1 THEN MIN(ip.MAX_Trans)       ELSE NULL  END Partition_MAX_Trans
                                  FROM   DBA_Indexes ii
                                  JOIN   DBA_Ind_Partitions ip ON ip.Index_Owner=ii.Owner AND ip.Index_Name =ii.Index_Name
                                  WHERE  ii.Table_Owner = ?
                                  AND    ii.Table_Name = ?
                                  GROUP BY ii.Index_Name
                                 ) p ON p.Index_Name = i.Index_Name
                 LEFT OUTER JOIN (SELECT ii.Index_Name, COUNT(*) SubPartition_Number,
                                  CASE WHEN COUNT(DISTINCT(ip.Tablespace_Name)) = 1 THEN MIN(ip.Tablespace_Name) ELSE NULL  END SubPartition_TS_Name,
                                  CASE WHEN COUNT(DISTINCT(ip.Status))          = 1 THEN MIN(ip.Status)          ELSE 'N/A' END SubPartition_Status,
                                  CASE WHEN COUNT(DISTINCT(ip.PCT_Free))        = 1 THEN MIN(ip.PCT_Free)        ELSE NULL  END SubPartition_PCT_Free,
                                  CASE WHEN COUNT(DISTINCT(ip.INI_Trans))       = 1 THEN MIN(ip.INI_Trans)       ELSE NULL  END SubPartition_INI_Trans,
                                  CASE WHEN COUNT(DISTINCT(ip.MAX_Trans))       = 1 THEN MIN(ip.MAX_Trans)       ELSE NULL  END SubPartition_MAX_Trans
                                  FROM   DBA_Indexes ii
                                  JOIN   DBA_Ind_SubPartitions ip ON ip.Index_Owner=ii.Owner AND ip.Index_Name =ii.Index_Name
                                  WHERE  ii.Table_Owner = ?
                                  AND    ii.Table_Name = ?
                                  GROUP BY ii.Index_Name
                                 ) sp ON sp.Index_Name = i.Index_Name
                 WHERE  i.Table_Owner = ? AND i.Table_Name = ?
                ", @owner, @table_name, @owner, @table_name, @owner, @table_name]

    @indexes.each do |i|
      columns = sql_select_all ["\
        SELECT ic.Column_Name, ie.Column_Expression
        FROM   DBA_Ind_Columns ic
        LEFT OUTER JOIN DBA_Ind_Expressions ie ON ie.Index_Owner = ic.Index_Owner AND ie.Index_Name=ic.Index_Name AND ie.Column_Position = ic.Column_Position
        WHERE  ic.Table_Owner = ?
        AND    ic.Index_Name  = ?
        ORDER BY ic.Column_Position", @owner, i.index_name]
      names = ""
      columns.each do |c|
        names << ", #{c.column_expression ? c.column_expression : c.column_name}"
      end
      i[:column_names] = names[2,names.length]

    end

    if @table_type == "materialized view"
      @viewtext = sql_select_one ["SELECT m.query
                                   FROM   sys.dba_mviews m
                                   WHERE  Owner      = ?
                                   AND    MView_Name = ?
                                   ", @owner, @table_name]
    end

    @unique_constraints = sql_select_all ["\
      SELECT c.*
      FROM   All_Constraints c
      WHERE  c.Constraint_Type = 'U'
      AND    c.Owner = ?
      AND    c.Table_Name = ?
      ", @owner, @table_name]

    @check_constraints = sql_select_all ["\
      SELECT c.*
      FROM   All_Constraints c
      WHERE  c.Constraint_Type = 'C'
      AND    c.Owner = ?
      AND    c.Table_Name = ?
      AND    Generated != 'GENERATED NAME' -- Ausblenden implizite NOT NULL Constraints
      ", @owner, @table_name]

    @references = sql_select_all ["\
      SELECT c.*, r.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows,
             (SELECT  wm_concat(column_name) FROM (SELECT *FROM All_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
             (SELECT  wm_concat(column_name) FROM (SELECT *FROM All_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
      FROM   All_Constraints c
      JOIN   All_Constraints r ON r.Owner = c.R_Owner AND r.Constraint_Name = c.R_Constraint_Name
      JOIN   All_Tables rt ON rt.Owner = r.Owner AND rt.Table_Name = r.Table_Name
      WHERE  c.Constraint_Type = 'R'
      AND    c.Owner      = ?
      AND    c.Table_Name = ?
      ", @owner, @table_name]

    @referencing = sql_select_all ["\
      SELECT c.*, ct.Num_Rows,
             (SELECT  wm_concat(column_name) FROM (SELECT *FROM All_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
             (SELECT  wm_concat(column_name) FROM (SELECT *FROM All_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
      FROM   All_Constraints r
      JOIN   All_Constraints c ON c.R_Owner = r.Owner AND c.R_Constraint_Name = r.Constraint_Name
      JOIN   All_Tables ct ON ct.Owner = c.Owner AND ct.Table_Name = c.Table_Name
      WHERE  c.Constraint_Type = 'R'
      AND    r.Owner      = ?
      AND    r.Table_Name = ?
      ", @owner, @table_name]


      render_partial "list_table_description"
  end

  def list_table_partitions
    @owner      = params[:owner]
    @table_name = params[:table_name]

    part_tab = sql_select_first_row ["SELECT Partitioning_Type, SubPartitioning_Type #{", Interval" if session[:database].version >= "11.2"} FROM DBA_Part_Tables WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]
    part_keys = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", @owner, @table_name]

    @partition_expression = "Partition by #{part_tab.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")}) #{"Interval #{part_tab.interval}" if session[:database].version >= "11.2" && part_tab.interval}"

    @partitions = sql_select_all ["\
      SELECT p.*, (SELECT SUM(Bytes)/(1024*1024)
                   FROM   DBA_Segments s
                   WHERE  s.Owner = p.Table_Owner AND s.Segment_Name = p.Table_Name AND s.Partition_Name = p.Partition_Name
                  ) Size_MB
      FROM DBA_Tab_Partitions p
      WHERE p.Table_Owner = ? AND p.Table_Name = ?
      ", @owner, @table_name]

    render_partial
  end

  def list_index_partitions
    @owner      = params[:owner]
    @index_name = params[:index_name]

    part_ind = sql_select_first_row ["SELECT Partitioning_Type, SubPartitioning_Type #{", Interval" if session[:database].version >= "11.2"} FROM DBA_Part_Indexes WHERE Owner = ? AND Index_Name = ?", @owner, @index_name]
    part_keys = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", @owner, @index_name]

    @partition_expression = "Partition by #{part_ind.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")}) #{"Interval #{part_ind.interval}" if session[:database].version >= "11.2" && part_ind.interval}"

    @partitions = sql_select_all ["\
      SELECT p.*, (SELECT SUM(Bytes)/(1024*1024)
                   FROM   DBA_Segments s
                   WHERE  s.Owner = p.Index_Owner AND s.Segment_Name = p.Index_Name AND s.Partition_Name = p.Partition_Name
                  ) Size_MB
      FROM DBA_Ind_Partitions p
      WHERE p.Index_Owner = ? AND p.Index_Name = ?
      ", @owner, @index_name]

    render_partial
  end


  def list_audit_trail
    where_string = ""
    where_values = []

    if params[:time_selection_start] && params[:time_selection_end]
      save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
      where_string << " AND  Timestamp >= TO_DATE(?, '#{sql_datetime_minute_mask}') AND Timestamp <  TO_DATE(?, '#{sql_datetime_minute_mask}')"
      where_values << @time_selection_start
      where_values << @time_selection_end
    end

    if params[:sessionid] && params[:sessionid]!=""
      @sessionid = params[:sessionid]
      where_string << " AND SessionID=?"
      where_values << @sessionid
    end

    if params[:os_user] && params[:os_user]!=""
      @os_user = params[:os_user]
      where_string << " AND UPPER(OS_UserName) LIKE UPPER('%'||?||'%')"
      where_values << @os_user
    end

    if params[:db_user] && params[:db_user]!=""
      @db_user = params[:db_user]
      where_string << " AND UPPER(UserName) LIKE UPPER('%'||?||'%')"
      where_values << @db_user
    end

    if params[:machine] && params[:machine]!=""
      @machine = params[:machine]
      where_string << " AND UPPER(UserHost) LIKE UPPER('%'||?||'%')"
      where_values << @machine
    end

    if params[:object_name] && params[:object_name]!=""
      @object_name = params[:object_name]
      where_string << " AND UPPER(Obj_Name) LIKE UPPER('%'||?||'%')"
      where_values << @object_name
    end

    if params[:action_name] && params[:action_name]!=""
      @action_name = params[:action_name]
      where_string << " AND UPPER(Action_Name) LIKE UPPER('%'||?||'%')"
      where_values << @action_name
    end

    if params[:grouping] && params[:grouping] != "none"
      list_audit_trail_grouping(params[:grouping], where_string, where_values, params[:update_area], params[:top_x].to_i)
    else
      @audits = sql_select_all ["\
                     SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ *
                     FROM   DBA_Audit_Trail
                     WHERE  1=1 #{where_string}
                     ORDER BY Timestamp
                    "].concat(where_values)

      render_partial
    end
  end

  # Gruppierte Ausgabe der Audit-Trail-Info
  def list_audit_trail_grouping(grouping, where_string, where_values, update_area, top_x)
    @grouping = grouping
    @top_x    = top_x

    audits = sql_select_all ["\
                   SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ *
                   FROM   (SELECT TRUNC(Timestamp, '#{grouping}') Begin_Timestamp,
                                  MAX(Timestamp)+1/1440 Max_Timestamp,  -- auf naechste ganze Minute aufgerundet
                                  UserHost, OS_UserName, UserName, Action_Name,
                                  COUNT(*)         Audits
                                  FROM   DBA_Audit_Trail
                                  WHERE  1=1 #{where_string}
                                  GROUP BY TRUNC(Timestamp, '#{grouping}'), UserHost, OS_UserName, UserName, Action_Name
                          )
                   ORDER BY Begin_Timestamp, Audits
                  "].concat(where_values)
    def create_new_audit_result_record(audit_detail_record)
      {
                :begin_timestamp => audit_detail_record.begin_timestamp,
                :max_timestamp   => audit_detail_record.max_timestamp,
                :audits   => 0,
                :machines => {},
                :os_users  => {},
                :db_users  =>{},
                :actions  => {}
      }
    end

    @audits = []
    machines = {}; os_users={}; db_users={}; actions={}
    if audits.count > 0
      ts = audits[0].begin_timestamp
      rec = create_new_audit_result_record(audits[0])
      @audits << rec
      audits.each do |a|
        # Gruppenwechsel
        if a.begin_timestamp != ts
          ts = a.begin_timestamp
          rec = create_new_audit_result_record(a)
          @audits << rec
        end
        rec[:audits] = rec[:audits] + a.audits
        rec[:max_timestamp] = a.max_timestamp if a.max_timestamp > rec[:max_timestamp]  # Merken des groessten Zeitstempels

        rec[:machines][a.userhost] = (rec[:machines][a.userhost] ||=0) + a.audits
        machines[a.userhost] = (machines[a.userhost] ||= 0) + a.audits  # Gesamtmenge je Maschine merken für Sortierung nach Top x

        rec[:os_users][a.os_username] = (rec[:os_users][a.os_username] ||=0) + a.audits
        os_users[a.os_username] = (os_users[a.os_username] ||= 0) + a.audits

        rec[:db_users][a.username] = (rec[:db_users][a.username] ||=0) + a.audits
        db_users[a.username] = (db_users[a.username] ||= 0) + a.audits

        rec[:actions][a.action_name] = (rec[:actions][a.action_name] ||=0) + a.audits
        actions[a.action_name] = (actions[a.action_name] ||= 0) + a.audits

      end
    end


    @audits.each do |a|
      a.extend SelectHashHelper
    end

    @machines = []
    machines.each do |key, value|
      @machines << { :machine=>key, :audits=>value}
    end
    @machines.sort!{ |x,y| y[:audits] <=> x[:audits] }
    while @machines.count > top_x
      @machines.delete_at(@machines.count-1)
    end

    @os_users = []
    os_users.each do |key, value|
      @os_users << { :os_user=>key, :audits=>value}
    end
    @os_users.sort!{ |x,y| y[:audits] <=> x[:audits] }
    while @os_users.count > top_x
      @os_users.delete_at(@os_users.count-1)
    end

    @db_users = []
    db_users.each do |key, value|
      @db_users << { :db_user=>key, :audits=>value}
    end
    @db_users.sort!{ |x,y| y[:audits] <=> x[:audits] }
    while @db_users.count > top_x
      @db_users.delete_at(@db_users.count-1)
    end

    @actions = []
    actions.each do |key, value|
      @actions << { :action_name=>key, :audits=>value}
    end
    @actions.sort!{ |x,y| y[:audits] <=> x[:audits] }
    while @actions.count > top_x
      @actions.delete_at(@actions.count-1)
    end

    render_partial
  end
end
