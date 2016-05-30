# encoding: utf-8
class DbaSchemaController < ApplicationController
  include DbaHelper

  # Einstieg in Seite (Menü-Action)
  def show_object_size
    @tablespaces = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
        TABLESPACE_NAME Name                                    
      FROM DBA_TableSpaces                                      
      ORDER BY 1 ");
    @tablespaces.insert(0, {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))


    @schemas = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
        UserName Name                                           
      FROM DBA_Users
      ORDER BY 1 ");
    @schemas.insert(0, {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba_schema/show_object_size" }');"}
    end
  end
  
  # Anlistung der Objekte
  def list_objects
    @tablespace_name = params[:tablespace][:name]   if params[:tablespace]
    @schema_name     = params[:schema][:name]       if params[:schema]
    filter           = params[:filter]
    segment_name     = params[:segment_name]
    if params[:showPartitions] == "1"
       groupBy = "Owner, Segment_Name, Tablespace_Name, Segment_Type, Partition_Name"
       partCol = "Partition_Name"
    else
       groupBy = "Owner, Segment_Name, Tablespace_Name, Segment_Type"
       partCol = "DECODE(Count(*),1,NULL,Count(*))"
    end

    where_string = ""
    where_values = []

    if !@tablespace_name.nil? && @tablespace_name != all_dropdown_selector_name
      where_string << " AND s.Tablespace_Name=?"
      where_values << @tablespace_name
    end

    if !@schema_name.nil? && @schema_name != all_dropdown_selector_name
      where_string << " AND s.Owner=?"
      where_values << @schema_name
    end

    if filter
      where_string << " AND UPPER(s.Segment_Name) LIKE UPPER('%'||?||'%')"
      where_values << filter
    end

    if segment_name
      where_string << " AND UPPER(s.Segment_Name) = UPPER(?)"
      where_values << segment_name
    end

    @objects = sql_select_iterator ["\
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
        CASE WHEN COUNT(DISTINCT Compression) <= 1 THEN MIN(Compression) ELSE '<several>' END Compression,
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
               DECODE(s.Segment_Type,
                 'TABLE',              t.Compression  ||#{get_db_version >= '11.2' ? "CASE WHEN   t.Compression != 'DISABLED' THEN ' ('||  t.Compress_For||')' END" : "''"},
                 'TABLE PARTITION',    tp.Compression ||#{get_db_version >= '11.2' ? "CASE WHEN  tp.Compression != 'DISABLED' THEN ' ('|| tp.Compress_For||')' END" : "''"},
                 'TABLE SUBPARTITION', tsp.Compression||#{get_db_version >= '11.2' ? "CASE WHEN tsp.Compression != 'DISABLED' THEN ' ('||tsp.Compress_For||')' END" : "''"},
                 'INDEX',              i.Compression,
                 'INDEX PARTITION',    ip.Compression,
                 'INDEX SUBPARTITION', isp.Compression,
               NULL) Compression,
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

    render_partial :list_objects
  end # objekte_nach_groesse

  def list_table_description
    @owner        = params[:owner].upcase         if params[:owner]
    @segment_name = params[:segment_name].upcase  if params[:segment_name]

    if @owner.nil? || @owner == ''
      @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Type FROM DBA_Objects WHERE SubObject_Name IS NULL AND Object_Name=?", @segment_name]
      @owner = @objects[0].owner if @objects.count == 1
      if @objects.count > 1
        render_partial :list_table_description_owner_choice
        return
      end
    end

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

    @attribs = sql_select_all ["SELECT t.*, o.Created, o.Last_DDL_Time, o.Object_ID Table_Object_ID,
                                       m.Inserts, m.Updates, m.Deletes, m.Last_DML, m.Truncated, m.Drop_Segments
                                FROM DBA_Tables t
                                JOIN DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name AND o.Object_Type = 'TABLE'
                                LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name,
                                                        SUM(Inserts) Inserts,
                                                        SUM(Updates) Updates,
                                                        SUM(Deletes) Deletes,
                                                        MAX(Timestamp) Last_DML,
                                                        CASE WHEN MAX(Truncated) = 'YES' THEN 'YES' ELSE 'NO' END Truncated,
                                                        SUM(Drop_Segments) Drop_Segments
                                                 FROM   DBA_Tab_Modifications
                                                 WHERE  Table_Owner = ?
                                                 AND    Table_Name  = ?
                                                 GROUP BY Table_Owner, Table_Name
                                                ) m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name
                                WHERE t.Owner = ? AND t.Table_Name = ?
                               ", @owner, @table_name, @owner, @table_name]

    @comment = sql_select_one ["SELECT Comments FROM DBA_Tab_Comments WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

    @columns = sql_select_all ["\
                 SELECT /*+ Panorama Ramm */
                       c.*, co.Comments,
                       NVL(c.Data_Precision, c.Char_Length)||CASE WHEN c.Char_Used='B' THEN ' Bytes' WHEN c.Char_Used='C' THEN ' Chars' ELSE '' END Precision,
                       l.Segment_Name LOB_Segment,
                       s.Density, s.Num_Buckets, s.Histogram
                       #{', u.*' if get_db_version >= '11.2'}  -- fuer normale User nicht sichtbar in 10g
                FROM   DBA_Tab_Columns c
                LEFT OUTER JOIN DBA_Col_Comments co       ON co.Owner = c.Owner AND co.Table_Name = c.Table_Name AND co.Column_Name = c.Column_Name
                LEFT OUTER JOIN DBA_Lobs l               ON l.Owner = c.Owner AND l.Table_Name = c.Table_Name AND l.Column_Name = c.Column_Name
                LEFT OUTER JOIN DBA_Objects o            ON o.Owner = c.Owner AND o.Object_Name = c.Table_Name AND o.Object_Type = 'TABLE'
                LEFT OUTER JOIN DBA_Tab_Col_Statistics s ON s.Owner = c.Owner AND s.Table_Name = c.Table_Name AND s.Column_Name = c.Column_Name
                #{'LEFT OUTER JOIN sys.Col_Usage$ u         ON u.Obj# = o.Object_ID AND u.IntCol# = c.Column_ID' if get_db_version >= '11.2'}  -- fuer normale User nicht sichtbar in 10g
                WHERE  c.Owner = ? AND c.Table_Name = ?
                ORDER BY c.Column_ID
               ", @owner, @table_name]

    if @attribs[0].partitioned == 'YES'
      partitions = sql_select_first_row ["SELECT COUNT(*) Anzahl, COUNT(DISTINCT Compression) Compression_Count, MIN(Compression) Compression
                                          #{', COUNT(DISTINCT Compress_For) Compress_For_Count, MIN(Compress_For) Compress_For' if get_db_version >= '11.2'}
                                          FROM DBA_Tab_Partitions WHERE  Table_Owner = ? AND Table_Name = ?", @owner, @table_name]
      @partition_count = partitions.anzahl
      if partitions.compression_count > 0
        @attribs.each do |a|
          a.compression = partitions.compression_count == 1 ? partitions.compression : "< #{partitions.compression_count} different >"
          a.compress_for = partitions.compress_for_count == 1 ? partitions.compress_for : "< #{partitions.compress_for_count} different >"  if get_db_version >= '11.2'
        end
      end

      subpartitions = sql_select_first_row ["SELECT COUNT(*) Anzahl, COUNT(DISTINCT Compression) Compression_Count, MIN(Compression) Compression
                                             #{', COUNT(DISTINCT Compress_For) Compress_For_Count, MIN(Compress_For) Compress_For' if get_db_version >= '11.2'}
                                             FROM DBA_Tab_SubPartitions WHERE  Table_Owner = ? AND Table_Name = ?", @owner, @table_name]
      @subpartition_count = subpartitions.anzahl
      if subpartitions.compression_count > 0
        @attribs.each do |a|
          a.compression = subpartitions.compression_count == 1 ? subpartitions.compression : "< #{subpartitions.compression_count} different >"
          a.compress_for = subpartitions.compress_for_count == 1 ? subpartitions.compress_for : "< #{subpartitions.compress_for_count} different >"  if get_db_version >= '11.2'
        end
      end
    else
      @partition_count = 0
      @subpartition_count = 0
    end

    @size_mb_table = sql_select_one ["SELECT /*+ Panorama Ramm */ SUM(Bytes)/(1024*1024) FROM DBA_Segments WHERE Owner = ? AND Segment_Name = ?", @owner, @table_name]


    @stat_prefs = ''
    if get_db_version >= "11.2"
      stat_prefs=sql_select_all ['SELECT * FROM Dba_Tab_Stat_Prefs WHERE Owner=? AND Table_Name=?', @owner, @table_name]
      stat_prefs.each do |s|
        @stat_prefs << "#{s.preference_name}=#{s.preference_value} "
      end
    end

    # Einzelzugriff auf DBA_Segments sicherstellen, sonst sehr lange Laufzeit
    @size_mb_total = sql_select_one ["SELECT SUM((SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner = t.Owner AND s.Segment_Name = t.Segment_Name))
                                      FROM (
                                            SELECT ? Owner, ? Segment_Name FROM DUAL
                                            UNION ALL
                                            SELECT Owner, Index_Name FROM DBA_Indexes WHERE Table_Owner = ? AND Table_Name = ?
                                            UNION ALL
                                            SELECT Owner, Segment_Name FROM DBA_Lobs WHERE Owner = ? AND Table_Name = ?
                                      ) t",
                                     @owner, @table_name, @owner, @table_name, @owner, @table_name
                                    ]


    @indexes = sql_select_one ['SELECT COUNT(*) FROM DBA_Indexes WHERE Table_Owner = ? AND Table_Name = ?', @owner, @table_name]

    if @table_type == "materialized view"
      @viewtext = sql_select_one ["SELECT m.query
                                   FROM   sys.dba_mviews m
                                   WHERE  Owner      = ?
                                   AND    MView_Name = ?
                                   ", @owner, @table_name]
    end

    @unique_constraints = sql_select_all ["\
      SELECT c.*
      FROM   DBA_Constraints c
      WHERE  c.Constraint_Type = 'U'
      AND    c.Owner = ?
      AND    c.Table_Name = ?
      ", @owner, @table_name]

    @unique_constraints.each do |u|
      u[:columns] = ''
      columns =  sql_select_all ["\
      SELECT Column_Name
      FROM   DBA_Cons_Columns
      WHERE  Owner = ?
      AND    Table_Name = ?
      AND    Constraint_Name = ?
      ORDER BY Position
      ", @owner, @table_name, u.constraint_name]
      columns.each do |c|
        u[:columns] << c.column_name+', '
      end
      u[:columns] = u[:columns][0...-2]                                         # Letzte beide Zeichen des Strings entfernen
    end

    @pkeys = sql_select_one ["SELECT COUNT(*) FROM DBA_Constraints WHERE Constraint_Type = 'P' AND Owner = ? AND Table_Name = ?", @owner, @table_name]

    @check_constraints = sql_select_one ["SELECT COUNT(*) FROM DBA_Constraints WHERE Constraint_Type = 'C' AND Owner = ? AND Table_Name = ? AND Generated != 'GENERATED NAME' /* Ausblenden implizite NOT NULL Constraints */", @owner, @table_name]

    @references_from = sql_select_one ["SELECT COUNT(*) FROM DBA_Constraints WHERE Constraint_Type = 'R' AND Owner = ? AND Table_Name = ?", @owner, @table_name]

    @references_to = sql_select_one ["\
      SELECT COUNT(*)
      FROM   DBA_Constraints r
      JOIN   DBA_Constraints c ON c.R_Owner = r.Owner AND c.R_Constraint_Name = r.Constraint_Name
      WHERE  c.Constraint_Type = 'R'
      AND    r.Owner      = ?
      AND    r.Table_Name = ?
      ", @owner, @table_name]

    @triggers = sql_select_one ["SELECT COUNT(*) FROM DBA_Triggers WHERE Table_Owner = ? AND Table_Name = ?", @owner, @table_name]

    @lobs = sql_select_one ["SELECT COUNT(*) FROM DBA_Lobs WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

    render_partial :list_table_description
  end

  private
  def get_partition_expression(owner, table_name)
    part_tab      = sql_select_first_row ["SELECT Partitioning_Type, SubPartitioning_Type #{", Interval" if get_db_version >= "11.2"} FROM DBA_Part_Tables WHERE Owner = ? AND Table_Name = ?", owner, table_name]
    part_keys     = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", owner, table_name]
    subpart_keys  = sql_select_all ["SELECT Column_Name FROM DBA_SubPart_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", owner, table_name]

    partition_expression = "Partition by #{part_tab.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")}) #{"Interval #{part_tab.interval}" if get_db_version >= "11.2" && part_tab.interval}"
    partition_expression << " Sub-Partition by #{part_tab.subpartitioning_type} (#{subpart_keys.map{|i| i.column_name}.join(",")})" if part_tab.subpartitioning_type != 'NONE'
    partition_expression
  end

  public
  def list_table_partitions
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @partition_expression = get_partition_expression(@owner, @table_name)

    @partitions = sql_select_all ["\
      WITH Storage AS (SELECT /*+ NO_MERGE */   NVL(sp.Partition_Name, s.Partition_Name) Partition_Name, SUM(Bytes)/(1024*1024) MB
                      FROM DBA_Segments s
                      LEFT OUTER JOIN DBA_Tab_SubPartitions sp ON sp.Table_Owner = s.Owner AND sp.Table_Name = s.Segment_Name AND sp.SubPartition_Name = s.Partition_Name
                      WHERE s.Owner = ? AND s.Segment_Name = ?
                      GROUP BY NVL(sp.Partition_Name, s.Partition_Name)
                      )
      SELECT  st.MB Size_MB, p.*
      FROM DBA_Tab_Partitions p
      LEFT OUTER JOIN Storage st ON st.Partition_Name = p.Partition_Name
      WHERE p.Table_Owner = ? AND p.Table_Name = ?
      ", @owner, @table_name, @owner, @table_name]

    render_partial
  end

  def list_table_subpartitions
    @owner          = params[:owner]
    @table_name     = params[:table_name]
    @partition_name = params[:partition_name]

    @partition_expression = get_partition_expression(@owner, @table_name)

    @subpartitions = sql_select_all ["\
      SELECT p.*, (SELECT SUM(Bytes)/(1024*1024)
                   FROM   DBA_Segments s
                   WHERE  s.Owner = p.Table_Owner AND s.Segment_Name = p.Table_Name AND s.Partition_Name = p.SubPartition_Name
                  ) Size_MB
      FROM DBA_Tab_SubPartitions p
      WHERE p.Table_Owner = ? AND p.Table_Name = ?
      #{" AND p.Partition_Name = ?" if @partition_name}
      ", @owner, @table_name, @partition_name]

    render_partial
  end

  def list_primary_key
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @pkeys = sql_select_all ["\
      SELECT * FROM DBA_constraints WHERE Owner = ? AND Table_Name = ? AND Constraint_Type = 'P'
      ", @owner, @table_name]

    if @pkeys.count > 0
      columns =  sql_select_all ["\
        SELECT Column_Name
        FROM   DBA_Cons_Columns
        WHERE  Owner = ?
        AND    Table_Name = ?
        AND    Constraint_Name = ?
        ORDER BY Position
        ", @owner, @table_name, @pkeys[0].constraint_name]
      @pkeys[0][:columns] = ''
      columns.each do |c|
        @pkeys[0][:columns] << c.column_name+', '
      end
      @pkeys[0][:columns] = @pkeys[0][:columns][0...-2]                                         # Letzte beide Zeichen des Strings entfernen
    end

    render_partial
  end


  def list_indexes
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @indexes = sql_select_all ["\
                 SELECT /*+ Panorama Ramm */ i.*, p.Partition_Number, sp.SubPartition_Number, Partition_TS_Name, SubPartition_TS_Name,
                        Partition_Status, SubPartition_Status, Partition_Pct_Free, SubPartition_Pct_Free,
                        Partition_Ini_Trans, SubPartition_Ini_Trans, Partition_Max_Trans, SubPartition_Max_Trans,
                        (SELECT SUM(Bytes)/(1024*1024)
                         FROM   DBA_Segments s
                         WHERE  s.Owner = i.Owner AND s.Segment_Name = i.Index_Name
                        ) Size_MB,
                        DECODE(bitand(io.flags, 65536), 0, 'NO', 'YES') Monitoring,
                        DECODE(bitand(ou.flags, 1), 0, 'NO', NULL, 'Unknown', 'YES') Used,
                        ou.start_monitoring, ou.end_monitoring,
                        do.Created, do.Last_DDL_Time
                 FROM   DBA_Indexes i
                 JOIN   DBA_Users   u  ON u.UserName  = i.owner
                 JOIN   sys.Obj$    o  ON o.Owner# = u.User_ID AND o.Name = i.Index_Name
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

    render_partial
  end


  def list_check_constraints
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @check_constraints = sql_select_all ["\
      SELECT c.*
      FROM   DBA_Constraints c
      WHERE  c.Constraint_Type = 'C'
      AND    c.Owner = ?
      AND    c.Table_Name = ?
      AND    Generated != 'GENERATED NAME' -- Ausblenden implizite NOT NULL Constraints
      ", @owner, @table_name]

    render_partial
  end

  def list_references_from
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @references = sql_select_all ["\
      SELECT c.*, r.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows,
             #{get_db_version >= "11.2" ?
                                      "(SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      "
                                  :
                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      "
                                  }
      FROM   DBA_Constraints c
      JOIN   DBA_Constraints r ON r.Owner = c.R_Owner AND r.Constraint_Name = c.R_Constraint_Name
      JOIN   DBA_Tables rt ON rt.Owner = r.Owner AND rt.Table_Name = r.Table_Name
      WHERE  c.Constraint_Type = 'R'
      AND    c.Owner      = ?
      AND    c.Table_Name = ?
      ", @owner, @table_name]

    render_partial
  end

  def list_references_to
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @referencing = sql_select_all ["\
      SELECT c.*, ct.Num_Rows,
             #{get_db_version >= "11.2" ?
                                      "(SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      "
                                   :
                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      "
                                   }
      FROM   DBA_Constraints r
      JOIN   DBA_Constraints c ON c.R_Owner = r.Owner AND c.R_Constraint_Name = r.Constraint_Name
      JOIN   DBA_Tables ct ON ct.Owner = c.Owner AND ct.Table_Name = c.Table_Name
      WHERE  c.Constraint_Type = 'R'
      AND    r.Owner      = ?
      AND    r.Table_Name = ?
      ", @owner, @table_name]

    render_partial
  end

  def list_triggers
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @triggers = sql_select_all ["\
      SELECT t.*
      FROM   DBA_Triggers t
      WHERE  t.Table_Owner = ?
      AND    t.Table_Name  = ?
      ", @owner, @table_name]

    render_partial
  end

  def list_trigger_body
    body = sql_select_one ["\
      SELECT Trigger_Body
      FROM   DBA_Triggers
      WHERE  Owner = ?
      AND    Trigger_Name  = ?
      ", params[:owner], params[:trigger_name]]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{my_html_escape(body).html_safe}');"}
    end
  end

  def list_index_partitions
    @owner      = params[:owner]
    @index_name = params[:index_name]

    part_ind = sql_select_first_row ["SELECT Partitioning_Type, SubPartitioning_Type #{", Interval" if get_db_version >= "11.2"} FROM DBA_Part_Indexes WHERE Owner = ? AND Index_Name = ?", @owner, @index_name]
    part_keys = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", @owner, @index_name]

    @partition_expression = "Partition by #{part_ind.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")}) #{"Interval #{part_ind.interval}" if get_db_version >= "11.2" && part_ind.interval}"

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


  def list_lobs
    @owner      = params[:owner]
    @table_name = params[:table_name]
    @segment_name = params[:segment_name]

    where_string = ''
    where_values = []

    if @owner && @owner != ''
      where_string << ' AND l.Owner = ?'
      where_values << @owner
    end

    if @table_name && @table_name != ''
      where_string << ' AND l.Table_Name = ?'
      where_values << @table_name
    end

    if @segment_name && @segment_name != ''
      where_string << ' AND l.Segment_Name = ?'
      where_values << @segment_name
    end

    @lobs = sql_select_all ["\
      SELECT /*+ Panorama Ramm */ l.*, (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner = l.Owner AND s.Segment_Name = l.Segment_Name) Size_MB,
             (SELECT COUNT(*) FROM DBA_Lob_Partitions p WHERE p.Table_Owner = l.Owner AND p.Table_Name = l.Table_Name AND p.Lob_Name = l.Segment_Name) Partition_Count,
             (SELECT COUNT(*) FROM DBA_Lob_SubPartitions p WHERE p.Table_Owner = l.Owner AND p.Table_Name = l.Table_Name AND p.Lob_Name = l.Segment_Name) SubPartition_Count
      FROM   DBA_Lobs l
      WHERE  1=1 #{where_string}"].concat(where_values)

    render_partial
  end

  def list_lob_partitions
    @owner      = params[:owner]
    @table_name = params[:table_name]
    @lob_name   = params[:lob_name]

    @partitions = sql_select_all ["\
      SELECT /*+ Panorama Ramm */ p.*, (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner = p.Table_Owner AND s.Segment_Name = p.Lob_Name AND s.Partition_Name = p.Lob_Partition_Name) Size_MB
      FROM   DBA_Lob_Partitions p
      WHERE  p.Table_Owner = ? AND p.Table_Name = ? AND p.Lob_Name = ?
      ", @owner, @table_name, @lob_name]

    render_partial
  end

  def list_lob_subpartitions
    @owner      = params[:owner]
    @table_name = params[:table_name]
    @lob_name   = params[:lob_name]

    @partitions = sql_select_all ["\
      SELECT /*+ Panorama Ramm */ p.*, (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner = p.Table_Owner AND s.Segment_Name = p.Lob_Name AND s.Partition_Name = p.Lob_SubPartition_Name) Size_MB
      FROM   DBA_Lob_SubPartitions p
      WHERE  p.Table_Owner = ? AND p.Table_Name = ? AND p.Lob_Name = ?
      ", @owner, @table_name, @lob_name]

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
      @audits = sql_select_iterator ["\
                     SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ *
                     FROM   DBA_Audit_Trail
                     WHERE  1=1 #{where_string}
                     ORDER BY Timestamp
                    "].concat(where_values)

      render_partial :list_audit_trail
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

    render_partial :list_audit_trail_grouping
  end

  def list_histogram
    @owner        = params[:owner]
    @table_name   = params[:table_name]
    @data_type    = params[:data_type]
    @column_name  = params[:column_name]
    @num_rows     = params[:num_rows]

    interpreted_endpoint_value = 'NULL'
    interpreted_endpoint_value = "TO_CHAR(TO_DATE(TRUNC(endpoint_value),'J')+(ENDPOINT_VALUE-TRUNC(ENDPOINT_VALUE)), '#{sql_datetime_second_mask}')" if @data_type == 'DATE'

    @histograms = sql_select_all ["SELECT h.*,
                                          NVL(Endpoint_Number - LAG(Endpoint_Number) OVER (ORDER BY Endpoint_Number), Endpoint_Number) * #{@num_rows} / MAX(Endpoint_Number) OVER () Num_Rows,
                                          #{interpreted_endpoint_value} Interpreted_Endpoint_Value
                                   FROM   DBA_Histograms h
                                   WHERE  Owner       = ?
                                   AND    Table_Name  = ?
                                   AND    Column_Name = ?
                                   ORDER BY Endpoint_Number
                                  ", @owner, @table_name, @column_name]
    render_partial
  end

  def list_object_nach_file_und_block
    @object = object_nach_file_und_block(params[:fileno], params[:blockno])
    #@object = "[Kein Object gefunden für Parameter FileNo=#{params[:fileno]}, BlockNo=#{params[:blockno]}]" unless @object
    render_partial
  end

  def list_gather_historic
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @operations = sql_select_all ["SELECT o.*,
                                           EXTRACT(HOUR FROM End_Time - Start_Time)*60*24 + EXTRACT(MINUTE FROM End_Time - Start_Time)*60 + EXTRACT(SECOND FROM End_Time - Start_Time) Duration
                                   FROM   sys.WRI$_OPTSTAT_OPR o
                                   WHERE  SUBSTR(Target, 1, DECODE(INSTR(target, '.', 1, 2), 0, 200, INSTR(target, '.', 1, 2)-1)) = ?  /* remove possibly following partition name */
                                   ORDER BY Start_Time DESC
                                  ", "#{@owner}.#{@table_name}"]

    @tab_history = sql_select_all ["SELECT t.*, o.Subobject_Name
                                    FROM   DBA_Objects o
                                    JOIN   sys.WRI$_OPTSTAT_TAB_HISTORY t ON t.Obj# = o.Object_ID
                                    WHERE  o.Owner       = ?
                                    AND    o.Object_Name = ?
                                    ORDER BY t.AnalyzeTime DESC
                                   ", @owner, @table_name]

    render_partial
  end

end
