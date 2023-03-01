# encoding: utf-8

require 'java'

class DbaSchemaController < ApplicationController
  include DbaHelper
  include DbaSchemaHelper

  def list_stored_settings
    @owner        = prepare_param(:owner)
    @object_name  = prepare_param(:object_name)
    @object_type  = prepare_param(:object_type)
    @settings = sql_select_all ["SELECT *
                                 FROM   DBA_Stored_Settings
                                 WHERE  Owner       = ?
                                 AND    Object_Name = ?
                                 AND    Object_Type = ?",
                                @owner, @object_name, @object_type]
    render_partial
  end

  def list_db_users
    @username     = prepare_param :username
    where_string = ''
    where_values = []

    if @username
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "UserName = ?"
      where_values << @username
    end


    @users = sql_select_iterator ["WITH Users AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM DBA_Users #{where_string}),
                                       Role_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Granted_Roles
                                                   FROM   DBA_Role_Privs
                                                   GROUP BY Grantee
                                                  ),
                                       Tab_Privs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Obj_Grants
                                                      FROM   DBA_Tab_Privs
                                                      GROUP BY Grantee
                                                     ),
                                       Granted_Tab_Privs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Grantor, COUNT(*) Granted_Obj_Grants
                                                              FROM   DBA_Tab_Privs
                                                              GROUP BY Grantor
                                                             ),
                                       Sys_Privs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Privilege_Cnt
                                                      FROM   DBA_Sys_Privs
                                                      GROUP BY Grantee
                                                     )
                                  SELECT u.*, p.Granted_Roles, s.Privilege_Cnt, t.Obj_Grants, gt.Granted_Obj_Grants
                                  FROM   Users u
                                  LEFT OUTER JOIN Role_Privs p ON p.Grantee = u.UserName
                                  LEFT OUTER JOIN Tab_Privs t ON t.Grantee = u.UserName
                                  LEFT OUTER JOIN Granted_Tab_Privs gt ON gt.Grantor = u.UserName
                                  LEFT OUTER JOIN Sys_Privs s ON s.Grantee = u.UserName
                                  ORDER BY u.UserName
                                 "].concat(where_values)
    render_partial
  end

  def list_roles
    @role     = prepare_param :role
    where_string = ''
    where_values = []

    if @role
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Role = ?"
      where_values << @role
    end

    @roles = sql_select_iterator ["WITH Roles AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM DBA_Roles #{where_string}),
                                       Role_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ Granted_Role, COUNT(*) Grantees
                                                      FROM   DBA_Role_Privs
                                                      GROUP BY Granted_Role
                                                     ),
                                       Granted_Role_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Roles_Granted
                                                              FROM   DBA_Role_Privs
                                                              GROUP BY Grantee
                                                             ),
                                       Tab_Privs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Obj_Grants
                                                      FROM   DBA_Tab_Privs
                                                      GROUP BY Grantee
                                                     ),
                                       Sys_Privs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ Grantee, COUNT(*) Privilege_Cnt
                                                      FROM   DBA_Sys_Privs
                                                      GROUP BY Grantee
                                                     )
                                  SELECT r.*, p.Grantees, gp.Roles_Granted, s.Privilege_Cnt, t.Obj_Grants
                                  FROM   Roles r
                                  LEFT OUTER JOIN Role_Privs p          ON p.Granted_Role = r.Role
                                  LEFT OUTER JOIN Granted_Role_Privs gp ON gp.Grantee = r.Role
                                  LEFT OUTER JOIN Tab_Privs t           ON t.Grantee = r.Role
                                  LEFT OUTER JOIN Sys_Privs s           ON s.Grantee = r.Role
                                  ORDER BY r.Role
                                 "].concat(where_values)
    render_partial
  end

  def list_role_grants
    @role     = prepare_param :role
    @grantee  = prepare_param :grantee
    where_string = ''
    where_values = []

    if @role
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Granted_Role = ?"
      where_values << @role
    end

    if @grantee
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Grantee = ?"
      where_values << @grantee
    end

    @role_grants =   sql_select_iterator ["WITH Role_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ *
                                                               FROM   DBA_Role_Privs p
                                                               #{where_string}
                                                              ),
                                                Users AS (SELECT /*+ NO_MERGE MATERIALIZE */ UserName FROM DBA_Users),
                                                Roles AS (SELECT /*+ NO_MERGE MATERIALIZE */ Role FROM DBA_Roles)
                                           SELECT p.*,
                                                 CASE WHEN u.UserName IS NOT NULL THEN 'USER'
                                                      WHEN r.Role IS NOT NULL THEN 'ROLE'
                                                 ELSE 'Unknown' END Grantee_Type
                                           FROM   Role_Privs p
                                           LEFT OUTER JOIN Users u ON u.UserName = p.Grantee
                                           LEFT OUTER JOIN Roles r ON r.Role = p.Grantee
                                           ORDER BY p.Grantee, p.Granted_Role
                                          "].concat(where_values)
    render_partial
  end

  def list_sys_privileges
    @privileges = sql_select_iterator "SELECT Privilege, COUNT(*) Grantees
                                       FROM   DBA_Sys_Privs
                                       GROUP BY Privilege
                                       ORDER BY Privilege
                                      "
    render_partial
  end

  def list_granted_sys_privileges
    @privilege  = prepare_param :privilege
    @grantee    = prepare_param :grantee
    where_string = ''
    where_values = []

    if @privilege
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Privilege = ?"
      where_values << @privilege
    end

    if @grantee
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Grantee = ?"
      where_values << @grantee
    end

    @privileges =   sql_select_iterator ["WITH Sys_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ *
                                                             FROM   DBA_Sys_Privs
                                                             #{where_string}
                                                            ),
                                                Users AS (SELECT /*+ NO_MERGE MATERIALIZE */ UserName FROM DBA_Users),
                                                Roles AS (SELECT /*+ NO_MERGE MATERIALIZE */ Role FROM DBA_Roles)
                                          SELECT p.*,
                                                 CASE WHEN u.UserName IS NOT NULL THEN 'USER'
                                                      WHEN r.Role IS NOT NULL THEN 'ROLE'
                                                 ELSE 'Unknown' END Grantee_Type
                                          FROM   Sys_Privs p
                                          LEFT OUTER JOIN Users u ON u.UserName = p.Grantee
                                          LEFT OUTER JOIN Roles r ON r.Role = p.Grantee
                                          ORDER BY p.Grantee, p.Privilege
                                         "].concat(where_values)
    render_partial
  end

  def list_obj_privileges
    @privileges = sql_select_iterator "SELECT Privilege, COUNT(*) Granted_Privs
                                       FROM   DBA_Tab_Privs
                                       GROUP BY Privilege
                                       ORDER BY Privilege
                                      "
    render_partial
  end

  def list_obj_grants
    @privilege  = prepare_param :privilege
    @grantee    = prepare_param :grantee
    @grantor    = prepare_param :grantor
    where_string = ''
    where_values = []

    if @privilege
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Privilege = ?"
      where_values << @privilege
    end

    if @grantee
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Grantee = ?"
      where_values << @grantee
    end

    if @grantor
      where_string << (where_string == '' ? "WHERE " : "AND ")
      where_string << "Grantor = ?"
      where_values << @grantor
    end

    @privileges =   sql_select_iterator ["WITH Tab_Privs AS (SELECT /*+ NO_MERGE MATERIALIZE */ *
                                                             FROM   DBA_Tab_Privs
                                                             #{where_string}
                                                            ),
                                                Users AS (SELECT /*+ NO_MERGE MATERIALIZE */ UserName FROM DBA_Users),
                                                Roles AS (SELECT /*+ NO_MERGE MATERIALIZE */ Role FROM DBA_Roles)
                                          SELECT p.*,
                                                 CASE WHEN u.UserName IS NOT NULL THEN 'USER'
                                                      WHEN r.Role IS NOT NULL THEN 'ROLE'
                                                 ELSE 'Unknown' END Grantee_Type
                                          FROM   Tab_Privs p
                                          LEFT OUTER JOIN Users u ON u.UserName = p.Grantee
                                          LEFT OUTER JOIN Roles r ON r.Role = p.Grantee
                                          ORDER BY p.Grantee, p.Privilege
                                         "].concat(where_values)
    render_partial
  end

  # Einstieg in Seite (Menü-Action)
  def show_object_size
    @tablespaces = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
        TABLESPACE_NAME Name                                    
      FROM DBA_TableSpaces                                      
      ORDER BY 1 ")
    @tablespaces.insert(0, {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))


    @schemas = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */ DISTINCT Owner Name
      FROM DBA_Segments
      ORDER BY 1 ")
    @schemas.insert(0, {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))

    render_partial
  end
  
  # Anlistung der Objekte
  def list_objects
    @tablespace_name = params[:tablespace][:name]   if params[:tablespace]
    @schema_name     = params[:schema][:name]       if params[:schema]
    @show_partitions = params[:showPartitions] == '1'

    @instance       = prepare_param_instance
    @sql_id         = prepare_param(:sql_id)
    @child_number   = prepare_param(:child_number)
    @child_address  = prepare_param(:child_address)

    filter           = prepare_param(:filter)
    segment_name     = prepare_param(:segment_name)

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
      where_string << " AND UPPER(s.Segment_Name) LIKE UPPER(?)"
      where_values << filter
    end

    if segment_name
      where_string << " AND UPPER(s.Segment_Name) = UPPER(?)"
      where_values << segment_name
    end

    # block for SQL_ID-conditions
    if @sql_id
      where_string << " AND (s.Owner, s.Segment_Name) IN (SELECT /*+ NO_MERGE */ DISTINCT Object_Owner, Object_Name
                                                          FROM   gv$SQL_Plan
                                                          WHERE  SQL_ID = ?"
      where_values << @sql_id

      if @instance
        where_string << " AND Inst_ID = ?"
        where_values << @instance
      end

      if @child_number
        where_string << " AND Child_Number = ?"
        where_values << @child_number
      end

      if @child_address
        where_string << " AND Child_Address = HEXTORAW(?)"
        where_values << @child_address
      end

      where_string << ")"
    end


    @objects = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
        RowNum,
        CASE WHEN Segment_Name LIKE 'SYS_LOB%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 8, 10)) )||')'
             WHEN Segment_Name LIKE 'SYS_IL%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 7, 10)) )||')'
             WHEN Segment_Name LIKE 'SYS_IOT_OVER%' THEN
              Segment_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Segment_Name, 14, 10)) )||')'
        ELSE Segment_Name
        END Segment_Name_Qual,
        x.*
      FROM (
      SELECT
        Segment_Name,
        Tablespace_Name,
        #{@show_partitions ? "Partition_Name" : "Count(*) Partition_Count"},
        SEGMENT_TYPE,
        Owner,                                                  
        SUM(EXTENTS)                    Used_Ext,               
        SUM(bytes)/(1024*1024)          MBytes,
        SUM(Blocks)                     Blocks,
        MIN(Initial_Extent)/1024        Min_Init_Ext_KB,
        MAX(Initial_Extent)/1024        Max_Init_Ext_KB,
        SUM(Initial_Extent)/1024        Sum_Init_Ext_KB,
        MIN(Next_Extent)/1024           Min_Next_Ext_KB,
        MAX(Next_Extent)/1024           Max_Next_Ext_KB,
        SUM(Next_Extent)/1024           Sum_Next_Ext_KB,
        MIN(Min_Extents)                Min_Min_Exts,
        MAX(Min_Extents)                Max_Min_Exts,
        SUM(Min_Extents)                Sum_Min_Exts,
        MIN(Max_Extents)                Min_Max_Exts,
        MAX(Max_Extents)                Max_Max_Exts,
        SUM(Max_Extents)                Sum_Max_Exts,
        #{"CASE WHEN COUNT(DISTINCT InMemory) = 1 THEN MIN(InMemory) ELSE '<'||COUNT(DISTINCT InMemory)||'>' END InMemory," if get_db_version >= '12.1.0.2'}
        SUM(Num_Rows)                   Num_Rows,
        SUM(Blocks * PCT_Free)  / SUM(Blocks) Pct_Free,     /* weighted value by number of blocks of partition */
        SUM(Blocks * Ini_Trans) / SUM(Blocks) Ini_Trans,    /* weighted value by number of blocks of partition */
        CASE WHEN COUNT(DISTINCT Compression) <= 1 THEN MIN(Compression) ELSE '<several>' END Compression,
        AVG(Avg_Row_Len)                Avg_RowLen,
        SUM(Empty_Blocks)               Empty_Blocks,
        AVG(Avg_Space)                  Avg_Space,
        MIN(Last_Analyzed)              Last_Analyzed,
        MAX(Last_DML_Timestamp)         Last_DML_Timestamp,
        MIN(Created)                    Created,
        MAX(Last_DDL_Time)              Last_DDL_Time,
        MAX(Spec_TS)                    Spec_TS,
        SUM(Leaf_Blocks)                Leaf_Blocks
      FROM (
        /* Views moved to with clause due to performance problems with 18.3 */
        WITH Tab_Modifications AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, SubPartition_Name, Timestamp FROM DBA_Tab_Modifications WHERE Partition_Name IS NULL),
             Segments          AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM DBA_Segments s        WHERE s.SEGMENT_TYPE<>'CACHE' #{where_string}),
             Objects           AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Object_Name, SubObject_Name, Created, Last_DDL_Time, Timestamp FROM DBA_Objects),
             Tables            AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression#{", Compress_For" if get_db_version >= '11.2'} FROM DBA_Tables),
             Tab_Partitions    AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Partition_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression#{", Compress_For" if get_db_version >= '11.2'} FROM DBA_Tab_Partitions),
             Tab_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, SubPartition_Name, Num_Rows, Pct_Free, Ini_Trans, Avg_Row_Len, Empty_Blocks, Avg_Space, Last_Analyzed, Compression#{", Compress_For" if get_db_version >= '11.2'} FROM DBA_Tab_SubPartitions),
             Indexes           AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Index_Type, Num_Rows, Pct_Free, Ini_Trans, Compression, Last_Analyzed, Leaf_Blocks FROM DBA_Indexes),
             Ind_Partitions    AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Partition_Name, Num_Rows, Pct_Free, Ini_Trans, Last_Analyzed, Compression, Leaf_Blocks FROM DBA_Ind_Partitions),
             Ind_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, SubPartition_Name, Num_Rows, Pct_Free, Ini_Trans, Last_Analyzed, Compression, Leaf_Blocks FROM DBA_Ind_SubPartitions),
             Ind_Row_Len       AS (SELECT /*+ NO_MERGE MATERIALIZE */ ic.Index_Owner, ic.Index_Name, SUM(tc.Avg_Col_Len) Avg_Rows_Len
                                   FROM   DBA_Ind_Columns ic
                                   JOIN   DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                                   GROUP BY ic.Index_Owner, ic.Index_Name ),
             Tab_Row_Len       AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, SUM(Avg_Col_Len) Avg_Rows_Len
                                   FROM   DBA_Tab_Columns
                                   GROUP BY Owner, Table_Name
                                  ),
             Lobs              AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Segment_Name, Compression FROM DBA_Lobs),
             Lob_Partitions    AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Lob_Name, Lob_Partition_Name, Compression FROM DBA_Lob_Partitions),
             Lob_SubPartitions AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Lob_Name, Lob_SubPartition_Name, Compression FROM DBA_Lob_SubPartitions)
        SELECT /*+ ORDERED USE_HASH(s o t tp tsp m i ip isp im l lp lsp) */
               s.Segment_Name,
               s.Partition_Name,                                
               s.Segment_Type,                                  
               s.Tablespace_Name,
               s.Owner,                                         
               s.Extents,                                       
               s.Bytes, s.Blocks,
               s.Initial_Extent, s.Next_Extent, s.Min_Extents, s.Max_Extents,
               o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS,
               #{"s.InMemory," if get_db_version >= '12.1.0.2'}
               DECODE(s.Segment_Type,                           
                 'TABLE',              t.Num_Rows,
                 'TABLE PARTITION',    tp.Num_Rows,
                 'TABLE SUBPARTITION', tsp.Num_Rows,
                 'INDEX',              i.Num_Rows,
                 'INDEX PARTITION',    ip.Num_Rows,
                 'INDEX SUBPARTITION', isp.Num_Rows,
               NULL) num_rows,
               DECODE(s.Segment_Type,
                 'TABLE',              t.Pct_Free,
                 'TABLE PARTITION',    tp.Pct_Free,
                 'TABLE SUBPARTITION', tsp.Pct_Free,
                 'INDEX',              i.Pct_Free,
                 'INDEX PARTITION',    ip.Pct_Free,
                 'INDEX SUBPARTITION', isp.Pct_Free,
               NULL) Pct_Free,
               DECODE(s.Segment_Type,
                 'TABLE',              t.Ini_Trans,
                 'TABLE PARTITION',    tp.Ini_Trans,
                 'TABLE SUBPARTITION', tsp.Ini_Trans,
                 'INDEX',              i.Ini_Trans,
                 'INDEX PARTITION',    ip.Ini_Trans,
                 'INDEX SUBPARTITION', isp.Ini_Trans,
               NULL) Ini_Trans,
               DECODE(s.Segment_Type,
                 'TABLE',              t.Compression  ||#{get_db_version >= '11.2' ? "CASE WHEN   t.Compression != 'DISABLED' THEN ' ('||  t.Compress_For||')' END" : "''"},
                 'TABLE PARTITION',    tp.Compression ||#{get_db_version >= '11.2' ? "CASE WHEN  tp.Compression != 'DISABLED' THEN ' ('|| tp.Compress_For||')' END" : "''"},
                 'TABLE SUBPARTITION', tsp.Compression||#{get_db_version >= '11.2' ? "CASE WHEN tsp.Compression != 'DISABLED' THEN ' ('||tsp.Compress_For||')' END" : "''"},
                 'INDEX',              i.Compression,
                 'INDEX PARTITION',    ip.Compression,
                 'INDEX SUBPARTITION', isp.Compression,
                 'LOBSEGMENT',         l.Compression,
                 'LOB PARTITION',      lp.Compression,
                 'LOB SUBPARTITION',   lsp.Compression,
               NULL) Compression,
               CASE WHEN s.Segment_Type = 'TABLE'              THEN t.Avg_Row_Len
                    WHEN s.Segment_Type = 'TABLE PARTITION'    THEN tp.Avg_Row_Len
                    WHEN s.Segment_Type = 'TABLE SUBPARTITION' THEN tsp.Avg_Row_Len
                    WHEN s.Segment_Type IN ('INDEX', 'INDEX PARTITION', 'INDEX_SUBPARTITION') AND i.Index_Type = 'NORMAL'    THEN irl.Avg_Rows_Len
                    WHEN s.Segment_Type = 'INDEX'              AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
                    WHEN s.Segment_Type = 'INDEX PARTITION'    AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
                    WHEN s.Segment_Type = 'INDEX SUBPARTITION' AND i.Index_Type = 'IOT - TOP' THEN trl.Avg_Rows_Len
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
               NULL) Last_Analyzed,
               DECODE(s.Segment_Type,
                 'TABLE',              m.Timestamp,
                 'TABLE PARTITION',    m.Timestamp,
                 'TABLE SUBPARTITION', m.Timestamp,
                 'INDEX',              im.Timestamp,
                 'INDEX PARTITION',    im.Timestamp,
                 'INDEX SUBPARTITION', im.Timestamp,
               NULL) Last_DML_Timestamp,
               DECODE(s.Segment_Type,
                 'TABLE',              NULL,
                 'TABLE PARTITION',    NULL,
                 'TABLE SUBPARTITION', NULL,
                 'INDEX',              i.Leaf_Blocks,
                 'INDEX PARTITION',    ip.Leaf_Blocks,
                 'INDEX SUBPARTITION', isp.Leaf_Blocks,
               NULL) Leaf_Blocks
        FROM Segments s
        LEFT OUTER JOIN Objects o                 ON o.Owner         = s.Owner       AND o.Object_Name          = s.Segment_name   AND NVL(s.Partition_Name, '-1') = NVL(o.SubObject_Name, '-1')
        LEFT OUTER JOIN Tables t                  ON t.Owner         = s.Owner       AND t.Table_Name           = s.segment_name
        LEFT OUTER JOIN Tab_Partitions tp         ON tp.Table_Owner  = s.Owner       AND tp.Table_Name          = s.segment_name   AND tp.Partition_Name        = s.Partition_Name
        LEFT OUTER JOIN Tab_SubPartitions tsp     ON tsp.Table_Owner = s.Owner       AND tsp.Table_Name         = s.segment_name   AND tsp.SubPartition_Name    = s.Partition_Name
        LEFT OUTER JOIN Tab_Modifications m       ON m.Table_Owner = t.Owner         AND m.Table_Name           = t.Table_Name     AND m.Partition_Name IS NULL    -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
        LEFT OUTER JOIN Indexes i                 ON i.Owner         = s.Owner       AND i.Index_Name           = s.segment_name
        LEFT OUTER JOIN Ind_Partitions ip         ON ip.Index_Owner  = s.Owner       AND ip.Index_Name          = s.segment_name   AND ip.Partition_Name        = s.Partition_Name
        LEFT OUTER JOIN Ind_SubPartitions isp     ON isp.Index_Owner = s.Owner       AND isp.Index_Name         = s.segment_name   AND isp.SubPartition_Name    = s.Partition_Name
        LEFT OUTER JOIN Ind_Row_Len irl           ON irl.Index_Owner = i.Owner       AND irl.Index_Name         = i.Index_Name
        LEFT OUTER JOIN Tab_Row_Len trl           ON trl.Owner       = i.Table_Owner AND trl.Table_Name         = i.Table_Name     /* Sum of column sizes for IOTs */
        LEFT OUTER JOIN Tables it                 ON it.Owner        = i.Table_Owner AND it.Table_Name          = i.Table_Name
        LEFT OUTER JOIN Tab_Modifications im      ON im.Table_Owner  = it.Owner      AND im.Table_Name          = it.Table_Name    AND im.Partition_Name IS NULL    -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
        LEFT OUTER JOIN Lobs l                    ON l.Owner         = s.Owner       AND l.Segment_Name         = s.Segment_Name
        LEFT OUTER JOIN Lob_Partitions lp         ON lp.Table_Owner  = s.Owner       AND lp.Lob_Name            = s.Segment_Name   AND lp.Lob_Partition_Name     = s.Partition_Name
        LEFT OUTER JOIN Lob_SubPartitions lsp     ON lsp.Table_Owner = s.Owner       AND lsp.Lob_Name           = s.Segment_Name   AND lsp.Lob_SubPartition_Name = s.Partition_Name
       )
      GROUP BY Owner, Segment_Name, Tablespace_Name, Segment_Type #{", Partition_Name" if @show_partitions }
      ) x
      ORDER BY x.MBytes DESC"
      ].concat(where_values)

    render_partial :list_objects
  end # objekte_nach_groesse

  private

  def get_dependencies_count(owner, object_name, object_type)
    sql_select_one ["SELECT SUM(Anzahl) FROM (SELECT COUNT(*) Anzahl FROM DBA_Dependencies WHERE Owner = ? AND Name = ? AND Type = ?
                                    UNION ALL SELECT COUNT(*) Anzahl FROM DBA_Dependencies WHERE Referenced_Owner = ? AND Referenced_Name = ? AND Referenced_Type = ?
                    )", owner, object_name, object_type, owner, object_name, object_type]
  end

  def get_grant_count(owner, object_name)
    sql_select_one ["SELECT COUNT(*) FROM DBA_Tab_Privs WHERE Owner = ? AND Table_Name = ?", owner, object_name]
  end

  public

  def list_object_description
    @owner = prepare_param(:owner)
    @owner       = @owner.upcase                  if @owner

    @object_name = prepare_param(:segment_name)
    @object_name = @object_name.upcase            if @object_name

    @object_type = prepare_param(:object_type)
    @object_type = @object_type.upcase            if @object_type

    show_popup_message "Object name must be set! At least with wildcard character (%, _)." if @object_name == ''

    case
      when @owner.nil? && @object_type.nil? then
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Object_Type FROM DBA_Objects WHERE SubObject_Name IS NULL AND Object_Name LIKE ?", @object_name]
      when @owner.nil?
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Object_Type FROM DBA_Objects WHERE SubObject_Name IS NULL AND Object_Name LIKE ? AND Object_Type = ?", @object_name, @object_type]
      when @object_type.nil?
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Object_Type FROM DBA_Objects WHERE SubObject_Name IS NULL AND Object_Name LIKE ? AND Owner LIKE ?", @object_name, @owner]
      else
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Object_Type FROM DBA_Objects WHERE SubObject_Name IS NULL AND Object_Name LIKE ? AND Owner LIKE ? AND Object_Type = ?", @object_name, @owner, @object_type]
    end

    if @objects.count > 1
      render_partial :list_table_description_owner_choice
      return
    end

    if @objects.count == 0 && @object_name =~ /^BIN\$/i                         # Try to find in recycle bin
      case
      when @owner.nil? && @object_type.nil? then
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Type FROM DBA_RecycleBin WHERE UPPER(Object_Name) LIKE ?", @object_name]
      when @owner.nil?
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Type FROM DBA_RecycleBin WHERE UPPER(Object_Name) LIKE ? AND Type = ?", @object_name, @object_type]
      when @object_type.nil?
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Type FROM DBA_RecycleBin WHERE UPPER(Object_Name) LIKE ? AND Owner LIKE ?", @object_name, @owner]
      else
        @objects = sql_select_all ["SELECT DISTINCT Owner, Object_Name, Type FROM DBA_RecycleBin WHERE UPPER(Object_Name) LIKE ? AND Owner LIKE ? AND Type = ?", @object_name, @owner, @object_type]
      end

      if @objects.count > 1
        render_partial :list_recyclebin_owner_choice
        return
      end

      if @objects.count == 1
        list_recyclebin_description(@objects[0].owner, @objects[0].object_name, @objects[0].type)
        return
      end

      show_popup_message "Object #{"#{@owner}." if @owner}#{@object_name}#{" with type #{@object_type}" if @object_type} does not exist in database as per DBA_OBJECTS and DBA_RECYCLEBIN"
      return
    end

    if @objects.count == 0
      show_popup_message "Object #{"#{@owner}." if @owner}#{@object_name}#{" with type #{@object_type}" if @object_type} does not exist in database as per DBA_OBJECTS"
      return
    end
    object = @objects[0]

    @owner                = object.owner
    @object_type          = object.object_type
    @object_name          = object.object_name
    params[:owner]        = @owner                                              # Vorbelegung falls Funktionsaufruf weitergegeben wird
    params[:object_name]  = @object_name                                        # Vorbelegung falls Funktionsaufruf weitergegeben wird
    params[:object_type]  = @object_type                                        # Vorbelegung falls Funktionsaufruf weitergegeben wird

    @table_type = "TABLE"
    @table_type = "MATERIALIZED VIEW" if @objects[0].object_type == "MATERIALIZED VIEW"

    # Ermitteln der zu dem Objekt gehörenden Table
    case @object_type
      when "TABLE", "TABLE PARTITION", "TABLE SUBPARTITION", "MATERIALIZED VIEW"
        if @object_name[0,12] == "SYS_IOT_OVER"
          res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @object_name[13,10]]
          raise PopupMessageException.new("Segment #{@owner}.#{@object_name} is not known table type") unless res
          @owner      = res.table_owner
          @table_name = res.table_name
        else
          @table_name = @object_name
        end
      when "INDEX", "INDEX PARTITION", "INDEX SUBPARTITION"
        if @object_name[0,6] == "SYS_IL"
          res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name, Object_Type Table_Type FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @object_name[6,10]]
        else
          res = sql_select_first_row ["SELECT Table_Owner, Table_Name, Table_Type FROM DBA_Indexes WHERE Owner=? AND Index_Name=?", @owner, @object_name]
        end
        raise "Segment #{@owner}.#{@object_name} is not known index type" unless res
        @owner      = res.table_owner
        @table_name = res.table_name
        case res.table_type
          when 'CLUSTER'
            list_cluster(@owner, @table_name)
            return
          when 'TABLE'
            params[:table_name] = @table_name
            params[:index_name] = @object_name
            list_indexes
            return
          else
            raise PopupMessageException.new("Segment #{@owner}.#{@object_name} is of unsupported type #{res.table_type}")
        end
      when "LOB"
        res = sql_select_first_row ["SELECT Owner Table_Owner, Object_Name Table_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(?)", @object_name[7,10]]
        show_popup_message("No corresponding table found for LOB segment '#{@object_name}'.\nPossibly dropped object from recycle bin?") if res.nil?
        @owner      = res.table_owner
        @table_name = res.table_name
      when "SEQUENCE"
        @seqs = sql_select_all ["SELECT * FROM DBA_Sequences WHERE Sequence_Owner = ? AND Sequence_Name = ?", @owner, @object_name]
        render_partial "list_sequence_description"
        return
      when 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE', 'TYPE BODY'
        list_plsql_description
        return
      when 'TRIGGER'
        rec = sql_select_first_row ["SELECT TRIM(Base_Object_Type) Base_Object_Type, Table_Owner, Table_Name FROM DBA_Triggers WHERE Owner=? AND Trigger_Name=?", @owner, @object_name]
        raise "No detail view available for trigger #{@owner}.#{@object_name} of base object type='#{rec.base_object_type}'" unless ['TABLE', 'VIEW'].include? rec.base_object_type
        params[:owner] = rec.table_owner
        params[:table_name] = rec.table_name
        list_triggers
        return
      when 'SYNONYM'
        list_synonym
        return
      when 'VIEW'
        list_view_description
        return
      when 'CLUSTER'
        list_cluster(@owner, @object_name)
        return
      else
        raise PopupMessageException.new("Segment #{@owner}.#{@object_name} of type #{object.object_type} is unsupported for detail view")
    end

    # assuming it is a table now
    # DBA_Tables is empty for XML-Tables, but DBA_All_Tables contains both object and relational tables
    @attribs = sql_select_all ["SELECT t.*,
                                       o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Object_ID Table_Object_ID,
                                       m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, #{"m.Truncated, " if get_db_version >= '11.2'}m.Drop_Segments,
                                       s.Size_MB_Table, s.Blocks Segment_Blocks, s.Extents,
                                       pt.Def_Tablespace_Name, pt.Def_PCT_Free, pt.Def_Ini_Trans, pt.Def_Max_Trans, pt.Def_Initial_extent, pt.Def_Next_Extent, pt.Def_Min_Extents, pt.Def_Max_Extents,
                                       pt.Def_Compression, pt.Def_Compress_For#{", pt.Def_InMemory" if get_db_version >= '12.1'}
                                       #{", ct.Clustering_Type, ct.On_Load CT_On_Load, ct.On_DataMovement CT_On_DataMovement, ct.Valid CT_Valid, ct.With_ZoneMap CT_With_Zonemap, ck.Clustering_Keys" if get_db_version >= '12.1.0.2'}
                                FROM DBA_All_Tables t
                                LEFT OUTER JOIN DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name AND o.Object_Type = 'TABLE'
                                LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name AND m.Partition_Name IS NULL    -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
                                LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) Size_MB_Table,
                                                                        SUM(Blocks) Blocks, SUM(Extents) Extents
                                                 FROM   DBA_Segments
                                                 WHERE  Owner = ? AND Segment_Name = ?
                                                 GROUP BY Owner, Segment_Name
                                                ) s ON s.Owner = t.Owner AND s.Segment_name = t.Table_Name
                                LEFT OUTER JOIN DBA_Part_Tables pt ON pt.Owner = t.Owner AND pt.Table_Name = t.Table_Name
                                #{"LEFT OUTER JOIN DBA_Clustering_Tables ct ON ct.Owner = t.Owner AND ct.Table_Name = t.Table_Name
                                LEFT OUTER JOIN (SELECT Owner, Table_Name, ListAgg(Detail_Column, ', ') WITHIN GROUP (ORDER BY Position) Clustering_Keys
                                                 FROM   DBA_Clustering_Keys
                                                 GROUP BY Owner, Table_Name
                                                ) ck ON ck.Owner = t.Owner AND ck.Table_Name = t.Table_Name" if get_db_version >= '12.1'}
                                WHERE t.Owner = ? AND t.Table_Name = ?
                               ", @owner, @table_name, @owner, @table_name]

    if sql_select_one("SELECT COUNT(1) FROM All_Views WHERE View_Name = 'DBA_XML_TABLES'") > 0 # View exists and is readable (only if XMLDB is installed)
      @xml_attribs = sql_select_all ["\
        SELECT t.*
        FROM DBA_XML_Tables t
        WHERE t.Owner = ? AND t.Table_Name = ?
        ", @owner, @table_name]
    else
      @xml_attribs = []
    end

    if PanoramaConnection.rac?
      @rac_attribs = sql_select_first_row ["SELECT MIN(i.GC_Mastering_Policy) GC_Mastering_Policy,  COUNT(DISTINCT i.GC_Mastering_Policy) GC_Mastering_Policy_Cnt,
                                                   MIN(i.Current_Master) + 1  Current_Master,       COUNT(DISTINCT i.Current_Master)      Current_Master_Cnt,
                                                   MIN(i.Previous_Master) + 1  Previous_Master,     COUNT(DISTINCT DECODE(i.Previous_Master, 32767, NULL, i.Previous_Master)) Previous_Master_Cnt,
                                                   SUM(i.Remaster_Cnt) Remaster_Cnt
                                            FROM   DBA_Objects o
                                            JOIN   V$GCSPFMASTER_INFO i ON i.Data_Object_ID = o.Data_Object_ID
                                            WHERE  o.Owner = ? AND o.Object_Name = ?
                                           ", @owner, @table_name]
    end

    @comment = sql_select_one ["SELECT Comments FROM DBA_Tab_Comments WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

    @columns = sql_select_all ["\
                 SELECT /*+ Panorama Ramm */
                       c.*, co.Comments,
                       CASE WHEN Data_Type LIKE '%CHAR%' THEN
                         c.Char_Length ||CASE WHEN c.Char_Used='B' THEN ' Bytes' WHEN c.Char_Used='C' THEN ' Chars' ELSE '' END
                       ELSE
                         TO_CHAR(c.Data_Precision)
                       END Precision,
                       l.Segment_Name LOB_Segment,
                       s.Density, s.Num_Buckets, s.Histogram
                       #{', u.*' if get_db_version >= '11.2' && !PanoramaConnection.autonomous_database?}  -- fuer normale User nicht sichtbar in 10g
                FROM   DBA_Tab_Columns c
                LEFT OUTER JOIN DBA_Col_Comments co       ON co.Owner = c.Owner AND co.Table_Name = c.Table_Name AND co.Column_Name = c.Column_Name
                LEFT OUTER JOIN DBA_Lobs l               ON l.Owner = c.Owner AND l.Table_Name = c.Table_Name AND l.Column_Name = c.Column_Name
                LEFT OUTER JOIN DBA_Objects o            ON o.Owner = c.Owner AND o.Object_Name = c.Table_Name AND o.Object_Type = 'TABLE'
                LEFT OUTER JOIN DBA_Tab_Col_Statistics s ON s.Owner = c.Owner AND s.Table_Name = c.Table_Name AND s.Column_Name = c.Column_Name
                #{'LEFT OUTER JOIN sys.Col_Usage$ u         ON u.Obj# = o.Object_ID AND u.IntCol# = c.Column_ID' if get_db_version >= '11.2' && !PanoramaConnection.autonomous_database?}  -- fuer normale User nicht sichtbar in 10g
                WHERE  c.Owner = ? AND c.Table_Name = ?
                ORDER BY c.Column_ID
               ", @owner, @table_name]

    # Set numeric values to string to allow overriding with "< x different >" for partitions
    @attribs.each do |a|
      a.initial_extent = fn((a.initial_extent/1024 rescue nil))               # string value in KB
      a.next_extent    = fn((a.next_extent/1024 rescue nil))                  # string value in KB
      a.min_extents    = fn(a.min_extents)
      a.max_extents    = fn(a.max_extents)
    end

    if @attribs.count > 0 && @attribs[0].partitioned == 'YES'
      partitions = sql_select_first_row ["SELECT COUNT(*) Anzahl,
                                                 COUNT(DISTINCT Compression)      Compression_Count,    MIN(Compression)     Compression,
                                                 COUNT(DISTINCT Tablespace_Name)  Tablespace_Count,     MIN(Tablespace_Name) Tablespace_Name,
                                                 COUNT(DISTINCT Pct_Free)         Pct_Free_Count,       MIN(Pct_Free)        Pct_Free,
                                                 COUNT(DISTINCT Ini_Trans)        Ini_Trans_Count,      MIN(Ini_Trans)       Ini_Trans,
                                                 COUNT(DISTINCT Max_Trans)        Max_Trans_Count,      MIN(Max_Trans)       Max_Trans,
                                                 COUNT(DISTINCT Initial_Extent)   Initial_Extent_Count, MIN(Initial_Extent)  Initial_Extent,
                                                 COUNT(DISTINCT Next_Extent)      Next_Extent_Count,    MIN(Next_Extent)     Next_Extent,
                                                 COUNT(DISTINCT Min_Extent)       Min_Extents_Count,    MIN(Min_Extent)      Min_Extents,
                                                 COUNT(DISTINCT Max_Extent)       Max_Extents_Count,    MIN(Max_Extent)      Max_Extents,
                                                 COUNT(DISTINCT Compress_For)     Compress_For_Count,   MIN(Compress_For)    Compress_For
                                            #{", COUNT(DISTINCT InMemory)         InMemory_Count,       MIN(InMemory)        InMemory" if get_db_version >= '12.1'}
                                          FROM DBA_Tab_Partitions WHERE  Table_Owner = ? AND Table_Name = ?", @owner, @table_name]
      @partition_count = partitions.anzahl

      subpartitions = sql_select_first_row ["SELECT COUNT(*) Anzahl,
                                                    COUNT(DISTINCT Compression)     Compression_Count,    MIN(Compression)      Compression,
                                                    COUNT(DISTINCT Tablespace_Name) Tablespace_Count,     MIN(Tablespace_Name)  Tablespace_Name,
                                                    COUNT(DISTINCT Pct_Free)        Pct_Free_Count,       MIN(Pct_Free)         Pct_Free,
                                                    COUNT(DISTINCT Ini_Trans)       Ini_Trans_Count,      MIN(Ini_Trans)        Ini_Trans,
                                                    COUNT(DISTINCT Max_Trans)       Max_Trans_Count,      MIN(Max_Trans)        Max_Trans,
                                                    COUNT(DISTINCT Initial_Extent)  Initial_Extent_Count, MIN(Initial_Extent)   Initial_Extent,
                                                    COUNT(DISTINCT Next_Extent)     Next_Extent_Count,    MIN(Next_Extent)      Next_Extent,
                                                    COUNT(DISTINCT Min_Extent)      Min_Extents_Count,    MIN(Min_Extent)       Min_Extents,
                                                    COUNT(DISTINCT Max_Extent)      Max_Extents_Count,    MIN(Max_Extent)       Max_Extents,
                                                    COUNT(DISTINCT Compress_For)    Compress_For_Count,   MIN(Compress_For)     Compress_For
                                               #{", COUNT(DISTINCT InMemory)        InMemory_Count,       MIN(InMemory)         InMemory" if get_db_version >= '12.1'}
                                             FROM DBA_Tab_SubPartitions WHERE  Table_Owner = ? AND Table_Name = ?", @owner, @table_name]
      @subpartition_count = subpartitions.anzahl

      @partition_attribs = sql_select_first_row ["\
        SELECT MIN(Created)       Min_Created,
               MAX(Created)       Max_Created,
               MAX(Last_DDL_Time) Last_DDL_Time,
               MAX(TO_DATE(Timestamp, 'YYYY-MM-DD:HH24:MI:SS')) Last_Spec_TS
        FROM   DBA_Objects
        WHERE  Owner = ?
        AND    Object_Name = ?
        AND    SubObject_Name IS NOT NULL
      ", @owner, @table_name]
      @attribs.each do |a|
        # a.initial_extent and a.next_extent are still characters in KB here

        a.compression       = partitions.compression_count  == 1 ? partitions.compression     : "< #{partitions.compression_count} different >"           if partitions.compression_count > 0
        a.compress_for      = partitions.compress_for_count == 1 ? partitions.compress_for    : "< #{partitions.compress_for_count} different >"          if partitions.compression_count > 0
        a.tablespace_name   = partitions.tablespace_count   == 1 ? partitions.tablespace_name : "< #{partitions.tablespace_count} different >"            if partitions.tablespace_count > 0
        a.pct_free          = partitions.pct_free_count     == 1 ? partitions.pct_free        : "< #{partitions.pct_free_count} different >"              if partitions.pct_free_count > 0
        a.ini_trans         = partitions.ini_trans_count    == 1 ? partitions.ini_trans       : "< #{partitions.ini_trans_count} different >"             if partitions.ini_trans_count > 0
        a.max_trans         = partitions.max_trans_count    == 1 ? partitions.max_trans       : "< #{partitions.max_trans_count} different >"             if partitions.max_trans_count > 0
        a.initial_extent    = partitions.initial_extent_count == 1 ? fn(partitions.initial_extent/1024) : "< #{partitions.initial_extent_count} different >" if partitions.initial_extent_count > 0
        a.next_extent       = partitions.next_extent_count  == 1 ? fn(partitions.next_extent/1024) : "< #{partitions.next_extent_count} different >"      if partitions.next_extent_count > 0
        a.min_extents       = partitions.min_extents_count  == 1 ? partitions.min_extents     : "< #{partitions.min_extents_count} different >"           if partitions.min_extents_count > 0
        a.max_extents       = partitions.max_extents_count  == 1 ? partitions.max_extents     : "< #{partitions.max_extents_count} different >"           if partitions.max_extents_count > 0
        a.inmemory          = partitions.inmemory_count     == 1 ? partitions.inmemory        : "< #{partitions.inmemory_count} different >"              if get_db_version >= '12.1' && partitions.inmemory_count > 0

        # Subpartition-Werte überschreiben evtl. die Partition-Werte wieder
        a.compression       = subpartitions.compression_count  == 1 ? subpartitions.compression     : "< #{subpartitions.compression_count} different >"   if subpartitions.compression_count > 0
        a.compress_for      = subpartitions.compress_for_count == 1 ? subpartitions.compress_for    : "< #{subpartitions.compress_for_count} different >"  if subpartitions.compression_count > 0
        a.tablespace_name   = subpartitions.tablespace_count   == 1 ? subpartitions.tablespace_name : "< #{subpartitions.tablespace_count} different >"    if subpartitions.tablespace_count > 0
        a.pct_free          = subpartitions.pct_free_count     == 1 ? subpartitions.pct_free        : "< #{subpartitions.pct_free_count} different >"      if subpartitions.pct_free_count > 0
        a.ini_trans         = subpartitions.ini_trans_count    == 1 ? subpartitions.ini_trans       : "< #{subpartitions.ini_trans_count} different >"     if subpartitions.ini_trans_count > 0
        a.max_trans         = subpartitions.max_trans_count    == 1 ? subpartitions.max_trans       : "< #{subpartitions.max_trans_count} different >"     if subpartitions.max_trans_count > 0
        a.initial_extent    = subpartitions.initial_extent_count == 1 ? fn(subpartitions.initial_extent/1024) : "< #{subpartitions.initial_extent_count} different >" if subpartitions.initial_extent_count > 0
        a.next_extent       = subpartitions.next_extent_count  == 1 ? fn(subpartitions.next_extent/1024) : "< #{subpartitions.next_extent_count} different >"  if subpartitions.next_extent_count > 0
        a.min_extents       = subpartitions.min_extents_count  == 1 ? subpartitions.min_extents     : "< #{subpartitions.min_extents_count} different >"   if subpartitions.min_extents_count > 0
        a.max_extents       = subpartitions.max_extents_count  == 1 ? subpartitions.max_extents     : "< #{subpartitions.max_extents_count} different >"   if subpartitions.max_extents_count > 0
        a.inmemory          = subpartitions.inmemory_count     == 1 ? subpartitions.inmemory        : "< #{subpartitions.inmemory_count} different >"      if get_db_version >= '12.1' && subpartitions.inmemory_count > 0
      end

      @partition_expression = get_table_partition_expression(@owner, @table_name)

    else
      @partition_count = 0
      @subpartition_count = 0
      @partition_expression = nil
    end

    @size_mb_table = sql_select_one ["SELECT /*+ Panorama Ramm */ SUM(Bytes)/(1024*1024) FROM DBA_Segments WHERE Owner = ? AND Segment_Name = ?", @owner, @table_name]


    @stat_prefs = []
    if get_db_version >= "11.2"
      stat_prefs=sql_select_all ['SELECT * FROM Dba_Tab_Stat_Prefs WHERE Owner=? AND Table_Name=?', @owner, @table_name]
      stat_prefs.each do |s|
        @stat_prefs << "#{s.preference_name}=#{s.preference_value}"
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

    @mv_attribs = nil                                                           # suppress warning: instance variable @viewtext not initialized
    if @table_type == "MATERIALIZED VIEW" || sql_select_one(["SELECT COUNT(*) FROM DBA_Objects WHERE Owner=? AND Object_Name=? AND Object_Type = 'MATERIALIZED VIEW'", @owner, @table_name]) > 0
      @mv_attribs = sql_select_first_row ["SELECT m.*
                                           FROM   DBA_MViews m
                                           WHERE  m.Owner      = ?
                                           AND    m.MView_Name = ?
                                           ", @owner, @table_name]
    end

    @mv_log_count = sql_select_one ["SELECT COUNT(*) FROM  DBA_MView_Logs WHERE Log_Owner = ? AND Master = ?", @owner, @table_name]

=begin # access on GV$Access is often too slow for usage
    @sessions_accessing_count = sql_select_one ["SELECT COUNT(*)
                                                 FROM   GV$Access a
                                                 LEFT OUTER JOIN GV$PX_Session pqc ON pqc.Inst_ID = a.Inst_ID AND pqc.SID = a.SID
                                                 WHERE  a.Owner  = ?
                                                 AND    a.Object = ?
                                                 AND    a.Type   = ?
                                                 AND    pqc.QCInst_ID IS NULL /* Session is not a PQ-slave */
                                                ", @owner, @table_name, @table_type];
=end

    # reuse for several constraint types because selection takes a bit
    @constraints = sql_select_all ["SELECT c.*, CASE WHEN Generated = 'GENERATED NAME' THEN 1 END notnull FROM DBA_Constraints c WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

    @unique_constraints = @constraints.select {|c| c.constraint_type == 'U'}
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

    @pkeys = @constraints.select {|c| c.constraint_type == 'P'}.count

    @check_constraints = @constraints.select {|c| c.constraint_type == 'C' && c.notnull.nil?}.count  # Ausblenden implizite NOT NULL Constraints

    @references_from = @constraints.select {|c| c.constraint_type == 'R'}.count

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

    @dependencies = get_dependencies_count(@owner, @table_name, @table_type)
    @grants       = get_grant_count(@owner, @table_name)

    render_partial :list_object_description
  end

  def list_distinct_values
    @owner        = prepare_param :owner
    @table_name   = prepare_param :table_name
    @column_name  = prepare_param :column_name
    @distinct_values = sql_select_iterator "\
      SELECT  \"#{@column_name}\" Column_Value, COUNT(*) Records
      FROM    \"#{@owner}\".\"#{@table_name}\"
      GROUP BY \"#{@column_name}\"
    "
    render_partial
  end

  private
  def get_table_partition_expression(owner, table_name)
    part_tab      = sql_select_first_row ["SELECT * FROM DBA_Part_Tables WHERE Owner = ? AND Table_Name = ?", owner, table_name]
    part_keys     = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", owner, table_name]
    subpart_keys  = sql_select_all ["SELECT Column_Name FROM DBA_SubPart_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", owner, table_name]

    partition_expression = "PARTITION BY #{part_tab.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")})"
    partition_expression << " INTERVAL #{part_tab.interval}" if get_db_version >= "11.2" && part_tab.interval
    partition_expression << " AUTOMATIC" if get_db_version >= "12.2" && part_tab.autolist == 'YES'
    partition_expression << " SUBPARTITION BY #{part_tab.subpartitioning_type} (#{subpart_keys.map{|i| i.column_name}.join(",")})" if part_tab.subpartitioning_type != 'NONE'
    partition_expression << " INTERVAL #{part_tab.interval_subpartition}" if get_db_version >= "12.2" && part_tab.interval_subpartition
    partition_expression << " AUTOMATIC" if get_db_version >= "12.2" && part_tab.autolist_subpartition == 'YES'
    partition_expression
  end

  def get_index_partition_expression(owner, index_name)

    part_ind      = sql_select_first_row ["SELECT * FROM DBA_Part_Indexes WHERE Owner = ? AND Index_Name = ?", owner, index_name]
    part_keys     = sql_select_all ["SELECT Column_Name FROM DBA_Part_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position",  owner, index_name]
    sub_part_keys = sql_select_all ["SELECT Column_Name FROM DBA_SubPart_Key_Columns WHERE Owner = ? AND Name = ? ORDER BY Column_Position", owner, index_name]

    partition_expression = "PARTITION BY #{part_ind.partitioning_type} (#{part_keys.map{|i| i.column_name}.join(",")})"
    partition_expression << " INTERVAL #{part_ind.interval}" if get_db_version >= "11.2" && part_ind.interval
    partition_expression << " AUTOMATIC" if get_db_version >= "12.2" && part_ind.autolist == 'YES'
    partition_expression << " SUBPARTITION BY #{part_ind.subpartitioning_type} (#{sub_part_keys.map{|i| i.column_name}.join(",")})" if part_ind.subpartitioning_type != 'NONE'
    partition_expression << " INTERVAL #{part_ind.interval_subpartition}" if get_db_version >= "12.2" && part_ind.interval_subpartition
    partition_expression << " AUTOMATIC" if get_db_version >= "12.2" && part_ind.autolist_subpartition == 'YES'
    partition_expression
  end

  public
  def list_table_partitions
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @partition_expression = get_table_partition_expression(@owner, @table_name)

    @partitions = sql_select_all ["\
      WITH Storage AS (SELECT /*+ NO_MERGE MATERIALIZE */   NVL(sp.Partition_Name, s.Partition_Name) Partition_Name, SUM(Bytes)/(1024*1024) MB,
                              SUM(s.Blocks) Blocks, SUM(s.Extents) Extents
                      FROM DBA_Segments s
                      LEFT OUTER JOIN DBA_Tab_SubPartitions sp ON sp.Table_Owner = s.Owner AND sp.Table_Name = s.Segment_Name AND sp.SubPartition_Name = s.Partition_Name
                      WHERE s.Owner = ? AND s.Segment_Name = ?
                      GROUP BY NVL(sp.Partition_Name, s.Partition_Name)
                      )
      SELECT  st.MB Size_MB, p.*,
              m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, #{"m.Truncated, " if get_db_version >= '11.2'}m.Drop_Segments,
              o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS,
              st.Blocks segment_blocks, st.Extents,
              sp.SubPartition_Count,
              SP_Compression_Count,     SP_Compression,
              SP_Tablespace_Count,      SP_Tablespace_Name,
              SP_Pct_Free_Count,        SP_Pct_Free,
              SP_Ini_Trans_Count,       SP_Ini_Trans,
              SP_Max_Trans_Count,       SP_Max_Trans,
              SP_Initial_Extent_Count,  SP_Initial_Extent,
              CASE WHEN Initial_Extent IS NOT NULL THEN Initial_Extent/1024 END Initial_Extent_KB
         #{", SP_Compress_For_Count,    SP_Compress_For,
              SP_InMemory_Count,        SP_InMemory" if get_db_version >= '12.1'}
         #{", mi.GC_Mastering_Policy,  mi.Current_Master + 1  Current_Master,  mi.Previous_Master + 1  Previous_Master, mi.Remaster_Cnt" if PanoramaConnection.rac?}
      FROM DBA_Tab_Partitions p
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = p.Table_Owner AND o.Object_Name = p.Table_Name AND o.SubObject_Name = p.Partition_Name AND o.Object_Type = 'TABLE PARTITION'
      LEFT OUTER JOIN Storage st ON st.Partition_Name = p.Partition_Name
      LEFT OUTER JOIN DBA_Tab_Modifications m ON  m.Table_Owner = p.Table_Owner AND m.Table_Name = p.Table_Name AND m.Partition_Name = p.Partition_Name AND m.SubPartition_Name IS NULL
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Partition_Name, COUNT(*) SubPartition_Count,
                              COUNT(DISTINCT Compression)     SP_Compression_Count,     MIN(Compression)      SP_Compression,
                              COUNT(DISTINCT Tablespace_Name) SP_Tablespace_Count,      MIN(Tablespace_Name)  SP_Tablespace_Name,
                              COUNT(DISTINCT Pct_Free)        SP_Pct_Free_Count,        MIN(Pct_Free)         SP_Pct_Free,
                              COUNT(DISTINCT Ini_Trans)       SP_Ini_Trans_Count,       MIN(Ini_Trans)        SP_Ini_Trans,
                              COUNT(DISTINCT Max_Trans)       SP_Max_Trans_Count,       MIN(Max_Trans)        SP_Max_Trans,
                              COUNT(DISTINCT Initial_Extent)  SP_Initial_Extent_Count,  MIN(Initial_Extent)   SP_Initial_Extent
                         #{", COUNT(DISTINCT Compress_For)    SP_Compress_For_Count,    MIN(Compress_For)     SP_Compress_For,
                              COUNT(DISTINCT InMemory)        SP_InMemory_Count,        MIN(InMemory)         SP_InMemory" if get_db_version >= '12.1'}
                       FROM   DBA_Tab_SubPartitions WHERE  Table_Owner = ? AND Table_Name = ?
                       GROUP BY Partition_Name
                      ) sp ON sp.Partition_Name = p.Partition_Name
      #{"LEFT OUTER JOIN V$GCSPFMASTER_INFO mi ON mi.Data_Object_ID = o.Data_Object_ID" if PanoramaConnection.rac?}
      WHERE p.Table_Owner = ? AND p.Table_Name = ?
      ", @owner, @table_name, @owner, @table_name, @owner, @table_name]
    @partitions.sort! {|a, b| b.high_value <=> a.high_value }

    @partitions.each do |p|
      if !p.subpartition_count.nil? && p.subpartition_count > 0
        p.compression       = p.sp_compression_count    == 1 ? p.sp_compression     : "< #{p.sp_compression_count} different >"           if p.sp_compression_count > 0
        p.compress_for      = p.sp_compress_for_count   == 1 ? p.sp_compress_for    : "< #{p.sp_compress_for_count} different >"          if get_db_version >= '12.1' && p.sp_compression_count > 0
        p.tablespace_name   = p.sp_tablespace_count     == 1 ? p.sp_tablespace_name : "< #{p.sp_tablespace_count} different >"            if p.sp_tablespace_count > 0
        p.pct_free          = p.sp_pct_free_count       == 1 ? p.sp_pct_free        : "< #{p.sp_pct_free_count} different >"              if p.sp_pct_free_count > 0
        p.ini_trans         = p.sp_ini_trans_count      == 1 ? p.sp_ini_trans       : "< #{p.sp_ini_trans_count} different >"             if p.sp_ini_trans_count > 0
        p.max_trans         = p.sp_max_trans_count      == 1 ? p.sp_max_trans       : "< #{p.sp_max_trans_count} different >"             if p.sp_max_trans_count > 0
        p.initial_extent_kb = p.sp_initial_extent_count == 1 ? fn(p.sp_initial_extent/1024)  : "< #{p.sp_initial_extent_count} different >"        if p.sp_initial_extent_count > 0
        p.inmemory          = p.sp_inmemory_count       == 1 ? p.sp_inmemory        : "< #{p.sp_inmemory_count} different >"              if get_db_version >= '12.1' && p.sp_inmemory_count > 0
      end
    end


    render_partial
  end

  def list_table_subpartitions
    @owner          = params[:owner]
    @table_name     = params[:table_name]
    @partition_name = params[:partition_name]

    @partition_expression = get_table_partition_expression(@owner, @table_name)

    @subpartitions = sql_select_all ["\
      SELECT sp.*, s.Bytes/(1024*1024) Size_MB, s.Blocks segment_blocks, s.extents,
             m.Inserts, m.Updates, m.Deletes, m.Timestamp Last_DML, #{"m.Truncated, " if get_db_version >= '11.2'}m.Drop_Segments,
             o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, p.High_Value Partition_High_Value
         #{", mi.GC_Mastering_Policy,  mi.Current_Master + 1  Current_Master,  mi.Previous_Master + 1  Previous_Master, mi.Remaster_Cnt" if PanoramaConnection.rac?}
      FROM DBA_Tab_SubPartitions sp
      JOIN DBA_Tab_Partitions p ON p.Table_Owner = sp.Table_Owner AND p.Table_Name = sp.Table_Name AND p.Partition_Name = sp.Partition_Name
      LEFT OUTER JOIN DBA_Segments s ON s.Owner = sp.Table_Owner AND s.Segment_Name = sp.Table_Name AND s.Partition_Name = sp.SubPartition_Name
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = sp.Table_Owner AND o.Object_Name = sp.Table_Name AND o.SubObject_Name = sp.SubPartition_Name AND o.Object_Type = 'TABLE SUBPARTITION'
      LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = sp.Table_Owner AND m.Table_Name = sp.Table_Name AND m.Partition_Name = sp.Partition_Name AND m.SubPartition_Name = sp.SubPartition_Name
      #{"LEFT OUTER JOIN V$GCSPFMASTER_INFO mi ON mi.Data_Object_ID = o.Data_Object_ID" if PanoramaConnection.rac?}
      WHERE sp.Table_Owner = ? AND sp.Table_Name = ?
      #{" AND sp.Partition_Name = ?" if @partition_name}
      ", @owner, @table_name, @partition_name]

    @subpartitions.sort! {|a, b| b.high_value <=> a.high_value }
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

  # FGA policies of table or view
  def list_object_policies
    @owner        = prepare_param :owner
    @object_name  = prepare_param :object_name
    @policies = sql_select_all ["SELECT * FROM DBA_Audit_Policies WHERE Object_Schema = ? AND Object_Name = ?", @owner, @object_name]
    render_partial
  end

  def list_indexes
    @owner      = params[:owner]
    @table_name = params[:table_name]
    @index_name = prepare_param(:index_name)

    where_string = ''
    where_values = []

    if @index_name
      where_string << " AND Index_Name = ?"
      where_values << @index_name
    end

    @indexes = sql_select_all ["\
                 WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ *
                                  FROM   DBA_Indexes
                                  WHERE  Table_Owner = ? AND Table_Name = ? #{where_string}
                                 ),
                 Tab_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Column_Name, Avg_Col_Len FROM DBA_Tab_Columns WHERE Owner = ? AND Table_Name = ?),
                 Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Column_Name, Column_Position
                                 FROM   DBA_Ind_Columns
                                 WHERE  (Index_Owner, Index_Name) IN (SELECT Owner, Index_Name FROM Indexes)
                                ),
                 Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Constraint_Name, Column_Name, Position
                                  FROM   DBA_Cons_Columns
                                  WHERE  Owner = ? AND Table_Name = ?
                                 ),
                 Ref_Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Constraint_Name
                                     FROM   DBA_Constraints
                                     WHERE  Owner = ? AND Table_Name = ?
                                     AND    Constraint_Type = 'R'
                                    ),
                 ObjectUsage AS (#{if get_db_version >= '12.1'
                                      "SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Start_Monitoring, End_Monitoring, Monitoring, Used
                                       FROM   DBA_Object_Usage
                                      "
                                    else
                                      "SELECT /*+ NO_MERGE MATERIALIZE */ u.UserName Owner, o.Name Index_Name, Start_Monitoring, End_Monitoring,
                                              DECODE(bitand(io.flags, 65536), 0, 'NO', 'YES') Monitoring,
                                              DECODE(bitand(ou.flags, 1), 0, 'NO', NULL, 'Unknown', 'YES') Used
                                       FROM   sys.object_usage ou
                                       JOIN   sys.Ind$ io ON io.Obj# = ou.Obj#
                                       JOIN   sys.Obj$ o  ON o.Obj# = ou.Obj#
                                       JOIN   DBA_Users u ON u.User_ID = o.Owner#
                                      "
                                    end
                                })
                 SELECT /*+ Panorama Ramm */ i.*,
                        p.Partition_Number, sp.SubPartition_Number,
                        NULL Size_MB, NULL Extents, NULL Segment_Blocks, /* this columns are selected separately */
                        ou.Monitoring,
                        ou.Used,
                        TO_DATE(ou.start_monitoring, 'MM/DD/YYYY HH24:MI:SS') Start_Monitoring,
                        TO_DATE(ou.end_monitoring,   'MM/DD/YYYY HH24:MI:SS') End_Monitoring,
                        do.Created, do.Last_DDL_Time, TO_DATE(do.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS,
                        CASE WHEN c.Constraint_Exists IS NOT NULL THEN 'Y' END Used_For_FK,
                        CASE WHEN i.Index_Type = 'IOT - TOP' THEN
                          (SELECT SUM(Avg_Col_Len) FROM Tab_Columns)
                        ELSE
                          col_len.Sum_Col_Len
                        END Avg_Row_Len,
                        pi.Def_Tablespace_Name, pi.Def_Pct_Free, pi.Def_Ini_Trans, pi.Def_Max_Trans, pi.Def_Initial_Extent, pi.Def_Next_Extent,
                        pi.Def_Min_Extents, pi.Def_Max_Extents,
                        p.P_Status_Count,         p.P_Status,
                        p.P_Compression_Count,    p.P_Compression,
                        p.P_Tablespace_Count,     p.P_Tablespace_Name,
                        p.P_Pct_Free_Count,       p.P_Pct_Free,
                        p.P_Ini_Trans_Count,      p.P_Ini_Trans,
                        p.P_Max_Trans_Count,      p.P_Max_Trans,
                        p.P_Initial_Extent_Count, p.P_Initial_Extent,
                        p.P_Next_Extent_Count,    p.P_Next_Extent,
                        p.P_Min_Extents_Count,    p.P_Min_Extents,
                        p.P_Max_Extents_Count,    p.P_Max_Extents,
                        sp.SP_Status_Count,       sp.SP_Status,
                        sp.SP_Compression_Count,  sp.SP_Compression,
                        sp.SP_Tablespace_Count,   sp.SP_Tablespace_Name,
                        sp.SP_Pct_Free_Count,     sp.SP_Pct_Free,
                        sp.SP_Ini_Trans_Count,    sp.SP_Ini_Trans,
                        sp.SP_Max_Trans_Count,    sp.SP_Max_Trans,
                        sp.SP_Initial_Extent_Count, sp.SP_Initial_Extent,
                        sp.SP_Next_Extent_Count,  sp.SP_Next_Extent,
                        sp.SP_Min_Extents_Count,  sp.SP_Min_Extents,
                        sp.SP_Max_Extents_Count,  sp.SP_Max_Extents
                        #{", mi.GC_Mastering_Policy, mi.GC_Mastering_Policy_Cnt, mi.Current_Master, mi.Current_Master, mi.Current_Master_Cnt, mi.Previous_Master, mi.Previous_Master_Cnt, mi.Remaster_Cnt" if PanoramaConnection.rac?}
                 FROM   Indexes i
                 LEFT OUTER JOIN DBA_Objects do ON do.Owner = i.Owner AND do.Object_Name = i.Index_Name AND do.Object_Type = 'INDEX'
                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ic.Index_Owner, ic.Index_Name, SUM(tc.Avg_Col_Len) Sum_Col_Len
                                  FROM Ind_Columns ic
                                  JOIN Tab_Columns tc ON tc.Column_Name = ic.Column_Name
                                  GROUP BY Index_Owner, Index_Name
                                 ) col_len ON col_len.Index_Owner = i.Owner AND col_len.Index_Name = i.Index_Name
                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ii.Index_Name, MIN(c.Constraint_Name) Constraint_Exists
                                  FROM   Indexes ii
                                  LEFT OUTER JOIN Ind_Columns ic ON ic.Index_Owner = ii.Owner AND ic.Index_Name = ii.Index_Name AND ic.Column_Position = 1 /* Columns for test of FK */
                                  LEFT OUTER JOIN Cons_Columns cc ON cc.Column_Name = ic.Column_Name AND cc.Position = 1 /* First columns of constraint */
                                  LEFT OUTER JOIN Ref_Constraints c ON c.Constraint_Name = cc.Constraint_Name
                                  GROUP BY ii.Index_Name
                                 ) c ON c.Index_Name = i.Index_Name
                 LEFT OUTER JOIN ObjectUsage ou ON ou.Owner = i.Owner AND ou.Index_Name = i.Index_Name
                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ii.Index_Name, COUNT(*) Partition_Number,
                                  COUNT(DISTINCT ip.Status)          P_Status_Count,          MIN(ip.Status)           P_Status,
                                  COUNT(DISTINCT ip.Compression)     P_Compression_Count,     MIN(ip.Compression)      P_Compression,
                                  COUNT(DISTINCT ip.Tablespace_Name) P_Tablespace_Count,      MIN(ip.Tablespace_Name)  P_Tablespace_Name,
                                  COUNT(DISTINCT ip.Pct_Free)        P_Pct_Free_Count,        MIN(ip.Pct_Free)         P_Pct_Free,
                                  COUNT(DISTINCT ip.Ini_Trans)       P_Ini_Trans_Count,       MIN(ip.Ini_Trans)        P_Ini_Trans,
                                  COUNT(DISTINCT ip.Max_Trans)       P_Max_Trans_Count,       MIN(ip.Max_Trans)        P_Max_Trans,
                                  COUNT(DISTINCT ip.Initial_Extent)  P_Initial_Extent_Count,  MIN(ip.Initial_Extent)   P_Initial_Extent,
                                  COUNT(DISTINCT ip.Next_Extent)     P_Next_Extent_Count,     MIN(ip.Next_Extent)      P_Next_Extent,
                                  COUNT(DISTINCT ip.Min_Extent)      P_Min_Extents_Count,     MIN(ip.Min_Extent)       P_Min_Extents,
                                  COUNT(DISTINCT ip.Max_Extent)      P_Max_Extents_Count,     MIN(ip.Max_Extent)       P_Max_Extents
                                  FROM   Indexes ii
                                  JOIN   DBA_Ind_Partitions ip ON ip.Index_Owner=ii.Owner AND ip.Index_Name =ii.Index_Name
                                  GROUP BY ii.Index_Name
                                 ) p ON p.Index_Name = i.Index_Name
                 LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ii.Index_Name, COUNT(*) SubPartition_Number,
                                  COUNT(DISTINCT ip.Status)          SP_Status_Count,         MIN(ip.Status)          SP_Status,
                                  COUNT(DISTINCT ip.Compression)     SP_Compression_Count,    MIN(ip.Compression)     SP_Compression,
                                  COUNT(DISTINCT ip.Tablespace_Name) SP_Tablespace_Count,     MIN(ip.Tablespace_Name) SP_Tablespace_Name,
                                  COUNT(DISTINCT ip.Pct_Free)        SP_Pct_Free_Count,       MIN(ip.Pct_Free)        SP_Pct_Free,
                                  COUNT(DISTINCT ip.Ini_Trans)       SP_Ini_Trans_Count,      MIN(ip.Ini_Trans)       SP_Ini_Trans,
                                  COUNT(DISTINCT ip.Max_Trans)       SP_Max_Trans_Count,      MIN(ip.Max_Trans)       SP_Max_Trans,
                                  COUNT(DISTINCT ip.Initial_Extent)  SP_Initial_Extent_Count, MIN(ip.Initial_Extent)  SP_Initial_Extent,
                                  COUNT(DISTINCT ip.Next_Extent)     SP_Next_Extent_Count,    MIN(ip.Next_Extent)     SP_Next_Extent,
                                  COUNT(DISTINCT ip.Min_Extent)      SP_Min_Extents_Count,    MIN(ip.Min_Extent)      SP_Min_Extents,
                                  COUNT(DISTINCT ip.Max_Extent)      SP_Max_Extents_Count,    MIN(ip.Max_Extent)      SP_Max_Extents
                                  FROM   Indexes ii
                                  JOIN   DBA_Ind_SubPartitions ip ON ip.Index_Owner=ii.Owner AND ip.Index_Name =ii.Index_Name
                                  GROUP BY ii.Index_Name
                                 ) sp ON sp.Index_Name = i.Index_Name
                 LEFT OUTER JOIN DBA_Part_Indexes pi ON pi.Owner = i.Owner AND pi.Index_Name = i.Index_Name
              #{"LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ ii.Index_Name, MIN(i.GC_Mastering_Policy) GC_Mastering_Policy,  COUNT(DISTINCT i.GC_Mastering_Policy) GC_Mastering_Policy_Cnt,
                                  MIN(i.Current_Master) + 1  Current_Master,       COUNT(DISTINCT i.Current_Master)      Current_Master_Cnt,
                                  MIN(i.Previous_Master) + 1  Previous_Master,     COUNT(DISTINCT DECODE(i.Previous_Master, 32767, NULL, i.Previous_Master)) Previous_Master_Cnt,
                                  SUM(i.Remaster_Cnt) Remaster_Cnt
                                  FROM   Indexes ii
                                  JOIN   DBA_Objects o ON o.Owner = ii.Owner AND o.Object_Name = ii.Index_Name
                                  JOIN   V$GCSPFMASTER_INFO i ON i.Data_Object_ID = o.Data_Object_ID
                                  GROUP BY ii.Index_Name
                                 ) mi ON mi.Index_Name = i.Index_Name" if PanoramaConnection.rac?}
                  ORDER BY i.Index_Name
                ",  @owner, @table_name]
                                  .concat(where_values)
                                  .concat([@owner, @table_name, @owner, @table_name, @owner, @table_name])
                                  .concat(PanoramaConnection.rac? ? [@owner, @table_name] : [])

    # Selected separately because of long runtime if executed within complex SQL
    index_sizes = sql_select_all ["\
      SELECT s.Owner, s.Segment_Name, SUM(s.Bytes)/(1024*1024) Size_MB, SUM(s.Extents) Extents, SUM(s.Blocks) segment_Blocks
      FROM   DBA_Indexes ii
      JOIN   DBA_Segments s ON s.Owner = ii.Owner AND s.Segment_Name = ii.Index_Name
      WHERE  s.Segment_Type LIKE 'INDEX%'
      AND    ii.Table_Owner = ?
      AND    ii.Table_Name = ?
      GROUP BY s.Owner, s.Segment_Name
    ", @owner, @table_name]

    if PanoramaConnection.rac?
      @rac_attribs = sql_select_first_row ["SELECT MIN(i.GC_Mastering_Policy) GC_Mastering_Policy,  COUNT(DISTINCT i.GC_Mastering_Policy) GC_Mastering_Policy_Cnt,
                                                   MIN(i.Current_Master) + 1  Current_Master,       COUNT(DISTINCT i.Current_Master)      Current_Master_Cnt,
                                                   MIN(i.Previous_Master) + 1  Previous_Master,     COUNT(DISTINCT DECODE(i.Previous_Master, 32767, NULL, i.Previous_Master)) Previous_Master_Cnt,
                                                   SUM(i.Remaster_Cnt) Remaster_Cnt
                                            FROM   DBA_Objects o
                                            JOIN   V$GCSPFMASTER_INFO i ON i.Data_Object_ID = o.Data_Object_ID
                                            WHERE  o.Owner = ? AND o.Object_Name = ?
                                           ", @owner, @table_name]
    end





    columns = sql_select_all ["\
        SELECT ic.Index_Name, ic.Column_Name, ie.Column_Expression
        FROM   DBA_Ind_Columns ic
        LEFT OUTER JOIN DBA_Ind_Expressions ie ON ie.Index_Owner = ic.Index_Owner AND ie.Index_Name=ic.Index_Name AND ie.Column_Position = ic.Column_Position
        WHERE  ic.Table_Owner = ?
        AND    ic.Table_Name  = ?
        ORDER BY ic.Column_Position", @owner, @table_name]

    @indexes.each do |i|
      # Set numeric values to string to allow overriding with "< x different >" for partitions
      i.initial_extent = fn((i.initial_extent/1024 rescue nil))               # string value in KB
      i.next_extent    = fn((i.next_extent/1024 rescue nil))                  # string value in KB
      i.min_extents    = fn(i.min_extents)
      i.max_extents    = fn(i.max_extents)

      # LEFT OUTER JOIN to separately selected sizes
      index_sizes.each do |s|
        if s.owner == i.owner && s.segment_name == i.index_name
          i.size_mb = s.size_mb
          i.extents = s.extents
          i.segment_blocks  = s.segment_blocks
        end
      end

      names = ''
      columns.each do |c|
        names << ", #{c.column_expression ? c.column_expression : c.column_name}" if i.index_name == c.index_name
      end
      i[:column_names] = names[2,names.length]

      if i.partition_number&.> 0
        i['partition_expression'] = get_index_partition_expression(i.owner, i.index_name)
      else
        i['partition_expression'] = nil
      end

      # Set values of partitions if they exist
      if !i.partition_number.nil? && i.partition_number > 0
        i.status            = i.p_status_count          == 1 ? i.p_status          : "< #{i.p_status_count} different >"                if i.p_status_count      > 0
        i.compression       = i.p_compression_count     == 1 ? i.p_compression     : "< #{i.p_compression_count} different >"           if i.p_compression_count > 0
        i.tablespace_name   = i.p_tablespace_count      == 1 ? i.p_tablespace_name : "< #{i.p_tablespace_count} different >"            if i.p_tablespace_count  > 0
        i.pct_free          = i.p_pct_free_count        == 1 ? i.p_pct_free        : "< #{i.p_pct_free_count} different >"              if i.p_pct_free_count    > 0
        i.ini_trans         = i.p_ini_trans_count       == 1 ? i.p_ini_trans       : "< #{i.p_ini_trans_count} different >"             if i.p_ini_trans_count   > 0
        i.max_trans         = i.p_max_trans_count       == 1 ? i.p_max_trans       : "< #{i.p_max_trans_count} different >"             if i.p_max_trans_count   > 0
        i.initial_extent    = i.p_initial_extent_count  == 1 ? fn(i.p_initial_extent/1024) : "< #{i.p_initial_extent_count} different >" if i.p_initial_extent_count > 0
        i.next_extent       = i.p_next_extent_count     == 1 ? fn(i.p_next_extent/1024) : "< #{i.p_next_extent_count} different >"      if i.p_next_extent_count > 0
        i.min_extents       = i.p_min_extents_count     == 1 ? i.p_min_extents     : "< #{i.p_min_extents_count} different >"           if i.p_min_extents_count   > 0
        i.max_extents       = i.p_max_extents_count     == 1 ? i.p_max_extents     : "< #{i.p_max_extents_count} different >"           if i.p_max_extents_count   > 0

        if !i.subpartition_number.nil? && i.subpartition_number > 0
          # Set values of subpartitions if they exist
          i.status            = i.sp_status_count         == 1 ? i.sp_status          : "< #{i.sp_status_count} different >"                if i.sp_status_count      > 0
          i.compression       = i.sp_compression_count    == 1 ? i.sp_compression     : "< #{i.sp_compression_count} different >"           if i.sp_compression_count > 0
          i.tablespace_name   = i.sp_tablespace_count     == 1 ? i.sp_tablespace_name : "< #{i.sp_tablespace_count} different >"            if i.sp_tablespace_count  > 0
          i.pct_free          = i.sp_pct_free_count       == 1 ? i.sp_pct_free        : "< #{i.sp_pct_free_count} different >"              if i.sp_pct_free_count    > 0
          i.ini_trans         = i.sp_ini_trans_count      == 1 ? i.sp_ini_trans       : "< #{i.sp_ini_trans_count} different >"             if i.sp_ini_trans_count   > 0
          i.max_trans         = i.sp_max_trans_count      == 1 ? i.sp_max_trans       : "< #{i.sp_max_trans_count} different >"             if i.sp_max_trans_count   > 0
          i.initial_extent    = i.sp_initial_extent_count == 1 ? fn(i.sp_initial_extent/1024) : "< #{i.sp_initial_extent_count} different >" if i.sp_initial_extent_count > 0
          i.next_extent       = i.sp_next_extent_count    == 1 ? fn(i.sp_next_extent/1024) : "< #{i.sp_next_extent_count} different >"      if i.sp_next_extent_count > 0
          i.min_extents       = i.sp_min_extents_count    == 1 ? i.sp_min_extents     : "< #{i.sp_min_extents_count} different >"           if i.sp_min_extents_count   > 0
          i.max_extents       = i.sp_max_extents_count    == 1 ? i.sp_max_extents     : "< #{i.sp_max_extents_count} different >"           if i.sp_max_extents_count   > 0
        end
      end
    end

    render_partial :list_indexes
  end

  def list_index_usage
    @owner      = prepare_param(:owner)
    @index_name = prepare_param(:index_name)
    @usage = sql_select_all ["SELECT *
                              FROM   DBA_Index_Usage
                              WHERE  Owner= ?
                              AND    Name = ?
                             ", @owner, @index_name]
    render_partial
  end

  private
  def get_session_consistent_gets
    sql_select_one ["SELECT Value FROM v$SesStat WHERE SID = USERENV('SID') AND Statistic# = ?", PanoramaConnection.stat_id_consistent_gets]
  end
  public

  def list_current_index_stats
    @table_owner = params[:table_owner]
    @table_name  = params[:table_name]
    @index_owner = params[:index_owner]
    @index_name  = params[:index_name]
    leaf_blocks  = params[:leaf_blocks]

    object_id = sql_select_one ["SELECT Object_ID FROM DBA_Objects WHERE Owner = ? AND Object_Name = ?", @index_owner, @index_name]

    consistent_gets_before = get_session_consistent_gets

    @stats = sql_select_all "\
      SELECT SUM(Row_Count) Row_Count,
             COUNT(*)       Used_Leaf_Block_Count,
             MIN(Row_Count) Min_Rows_Per_Leaf_Block,
             MAX(Row_Count) Max_Rows_Per_Leaf_Block,
             AVG(Row_Count) Avg_Rows_per_Leaf_Block
      FROM   (
              SELECT COUNT(*) Row_Count, Block_ID
              FROM   (
                      SELECT /*+ INDEX_FFS(tab #{@index_name}) */ sys_op_lbid(#{object_id}, 'L', rowid) block_id
                      FROM   #{@table_owner}.#{@table_name} tab
                     )
              GROUP BY Block_ID
             )
       "

    @consistent_gets = get_session_consistent_gets - consistent_gets_before

    @stats.each do |s|
      s['total_leaf_blocks'] = leaf_blocks&.to_i
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
    @owner            = params[:owner]
    @table_name       = params[:table_name]
    @constraint_name  = prepare_param(:constraint_name)
    @index_owner      = prepare_param(:index_owner)
    @index_name       = prepare_param(:index_name)

    where_string = ''
    where_values = []

    if @constraint_name
      where_string << "AND c.Constraint_Name = ?"
      where_values << @constraint_name
    end

    if @index_owner && @index_name
      where_string << "AND c.Constraint_Name IN (SELECT cc.Constraint_Name
                                                 FROM   DBA_Ind_Columns ic
                                                 JOIN   DBA_Cons_Columns cc ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name AND cc.Position = 1 AND ic.Column_Position = 1
                                                 WHERE  ic.Index_Owner = ?
                                                 AND    ic.Index_Name  = ?
                                                )"
      where_values << @index_owner
      where_values << @index_name
    end

    @references = sql_select_all ["\
      WITH Cons_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, Column_Name, Position FROM DBA_Cons_Columns WHERE Owner = ? AND Table_Name = ?),
           Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_Name FROM DBA_Ind_Columns WHERE Table_Owner = ? AND Table_Name = ?)
      SELECT c.*, r.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows, pi.Min_Index_Owner, pi.Min_Index_Name, pi.Index_Number, rt.Last_Analyzed, m.Inserts, m.Updates, m.Deletes,
             #{get_db_version >= "11.2" ?
                                      "(SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      " :
                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns
                                      "
                                  }
      FROM   DBA_Constraints c
      JOIN   DBA_Constraints r    ON r.Owner = c.R_Owner AND r.Constraint_Name = c.R_Constraint_Name
      JOIN   DBA_Tables rt        ON rt.Owner = r.Owner AND rt.Table_Name = r.Table_Name
      LEFT OUTER JOIN DBA_Tab_Modifications m ON m.Table_Owner = rt.Owner AND m.Table_Name = rt.Table_Name AND m.Partition_Name IS NULL    -- Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen
      LEFT OUTER JOIN   (
              SELECT Owner, Constraint_Name,
                     MIN(Index_Owner) KEEP (DENSE_RANK FIRST ORDER BY Index_Name) Min_Index_Owner, MIN(Index_Name) Min_Index_Name,
                     COUNT(*) Index_Number
              FROM   (
                      SELECT Owner, Constraint_Name, Index_Owner, Index_Name
                      FROM   (SELECT cc.Owner, cc.Table_Name, cc.Constraint_Name, ic.Index_Owner, ic.Index_Name, ic.Column_Name Index_Column_Name,
                                     COUNT(DISTINCT cc.Column_Name) OVER (PARTITION BY cc.Owner, cc.Table_Name, cc.Constraint_Name) Cons_Column_Count
                              FROM   Cons_Columns cc
                              LEFT OUTER JOIN Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name AND ic.Column_name = cc.Column_Name
                              )
                      GROUP BY Owner, Constraint_Name, Index_Owner, Index_Name
                      HAVING MIN(Cons_Column_Count) = COUNT(DISTINCT Index_Column_Name) /* All FK columns must exist in protecting index, no matter in which order */
                     )
              GROUP BY Owner, Constraint_Name
             )  pi ON pi.Owner = c.Owner AND pi.Constraint_Name = c.Constraint_Name
      WHERE  c.Constraint_Type = 'R'
      AND    c.Owner      = ?
      AND    c.Table_Name = ?
      #{where_string}
      ", @owner, @table_name, @owner, @table_name, @owner, @table_name].concat(where_values)

    render_partial
  end

  def list_references_to
    @owner      = params[:owner]
    @table_name = params[:table_name]

    @referencing = sql_select_all ["\
      SELECT c.*, ct.Num_Rows,  pi.Min_Index_Owner, pi.Min_Index_Name, pi.Index_Number,
             #{get_db_version >= "11.2" ?
                                      "(SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY Position) FROM DBA_Cons_Columns cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      " :
                                      "(SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = r.Owner AND cc.Constraint_Name = r.Constraint_Name) R_Columns,
                                       (SELECT  wm_concat(column_name) FROM (SELECT * FROM DBA_Cons_Columns ORDER BY Position) cc WHERE cc.Owner = c.Owner AND cc.Constraint_Name = c.Constraint_Name) Columns
                                      "
                                   }
      FROM   DBA_Constraints r
      JOIN   DBA_Constraints c ON c.R_Owner = r.Owner AND c.R_Constraint_Name = r.Constraint_Name
      JOIN   DBA_Tables ct ON ct.Owner = c.Owner AND ct.Table_Name = c.Table_Name
      LEFT OUTER JOIN   (
              SELECT Owner, Constraint_Name,
                     MIN(Index_Owner) KEEP (DENSE_RANK FIRST ORDER BY Index_Name) Min_Index_Owner, MIN(Index_Name) Min_Index_Name,
                     COUNT(*) Index_Number
              FROM   (
                      SELECT Owner, Constraint_Name, Index_Owner, Index_Name
                      FROM   (SELECT cc.Owner, cc.Table_Name, cc.Constraint_Name, ic.Index_Owner, ic.Index_Name, ic.Column_Name Index_Column_Name,
                                     COUNT(DISTINCT cc.Column_Name) OVER (PARTITION BY cc.Owner, cc.Table_Name, cc.Constraint_Name) Cons_Columns
                              FROM   DBA_Cons_Columns cc
                              LEFT OUTER JOIN DBA_Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name AND ic.Column_name = cc.Column_Name
                              )
                      GROUP BY Owner, Constraint_Name, Index_Owner, Index_Name
                      HAVING MIN(Cons_Columns) = COUNT(DISTINCT Index_Column_Name)  /* All FK columns must exist in protecting index, no matter in which order */
                     )
              GROUP BY Owner, Constraint_Name
             )  pi ON pi.Owner = c.Owner AND pi.Constraint_Name = c.Constraint_Name
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
      SELECT t.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS
      FROM   DBA_Triggers t
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Trigger_Name AND o.Object_Type = 'TRIGGER'
      WHERE  t.Table_Owner = ?
      AND    t.Table_Name  = ?
      ", @owner, @table_name]

    render_partial :list_triggers
  end

  def list_dependencies
    @owner       = params[:owner]
    @object_name = params[:object_name]
    @object_type = params[:object_type]

    @dependencies_from_me = sql_select_all ["SELECT d.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Status,
                                                    (SELECT COUNT(*) FROM DBA_Dependencies di WHERE di.Referenced_Owner =d.Owner AND di.Referenced_Name = d.Name AND di.Referenced_Type = d.Type) Depending
                                             FROM   DBA_Dependencies d
                                             LEFT OUTER JOIN DBA_Objects o ON o.Owner = d.Owner AND o.Object_Name = d.Name AND o.Object_Type = d.Type AND o.SubObject_Name IS NULL
                                             WHERE  d.Referenced_Owner = ?
                                             AND    d.Referenced_Name = ?
                                             AND    d.Referenced_Type = ?
                                            ", @owner, @object_name, @object_type]

    @dependencies_im_from = sql_select_all ["SELECT d.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Status,
                                                    (SELECT COUNT(*) FROM DBA_Dependencies di WHERE di.Owner =d.Referenced_Owner AND di.Name = d.Referenced_Name AND di.Type = d.Referenced_Type) Depending
                                             FROM   DBA_Dependencies d
                                             LEFT OUTER JOIN DBA_Objects o ON o.Owner = d.Referenced_Owner AND o.Object_Name = d.Referenced_Name AND o.Object_Type = d.Referenced_Type AND o.SubObject_Name IS NULL
                                             WHERE  d.Owner = ?
                                             AND    d.Name = ?
                                             AND    d.Type = ?
                                            ", @owner, @object_name, @object_type]

    render_partial
  end

  def list_dependencies_from_me_tree
    @owner       = params[:owner]
    @object_name = params[:object_name]
    @object_type = params[:object_type]

    @dependencies_from_me = sql_select_iterator ["\
      SELECT x.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS
      FROM   (
              SELECT Level, DECODE(CONNECT_BY_ISCYCLE, 1, 'YES') CONNECT_BY_ISCYCLE, d.*
              FROM   DBA_Dependencies d
              CONNECT BY NOCYCLE PRIOR Owner = Referenced_Owner AND PRIOR Name = Referenced_Name AND PRIOR Type = Referenced_Type
              START WITH Referenced_Owner = ?
              AND        Referenced_Name  = ?
              AND        Referenced_Type  = ?
             ) x
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = x.Owner AND o.Object_Name = x.Name AND o.Object_Type = x.Type AND o.SubObject_Name IS NULL
      ", @owner, @object_name, @object_type]

    render_partial
  end

  def list_dependencies_im_from_tree
    @owner       = params[:owner]
    @object_name = params[:object_name]
    @object_type = params[:object_type]

    @dependencies_im_from = sql_select_iterator ["\
      SELECT x.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS
      FROM   (
              SELECT Level, DECODE(CONNECT_BY_ISCYCLE, 1, 'YES') CONNECT_BY_ISCYCLE, d.*
              FROM   DBA_Dependencies d
              CONNECT BY NOCYCLE PRIOR Referenced_Owner = Owner AND PRIOR Referenced_Name = Name AND PRIOR Referenced_Type = Type
              START WITH Owner = ?
              AND        Name  = ?
              AND        Type  = ?
             ) x
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = x.Referenced_Owner AND o.Object_Name = x.Referenced_Name AND o.Object_Type = x.Referenced_Type AND o.SubObject_Name IS NULL
      ", @owner, @object_name, @object_type]

    render_partial
  end

  def list_grants
    @owner       = params[:owner]
    @object_name = params[:object_name]

    @grants = sql_select_iterator ["SELECT p.*,
                                           CASE WHEN u.UserName IS NOT NULL THEN 'USER'
                                                WHEN r.Role IS NOT NULL THEN 'ROLE'
                                           ELSE 'Unknown' END Grantee_Type
                                    FROM   DBA_Tab_Privs p
                                    LEFT OUTER JOIN DBA_Users u ON u.UserName = p.Grantee
                                    LEFT OUTER JOIN DBA_Roles r ON r.Role = p.Grantee
                                    WHERE  p.Owner = ? AND p.Table_Name = ?", @owner, @object_name]
    render_partial
  end

  def list_dependency_grants
    @owner       = params[:owner]
    @object_name = params[:object_name]

    @grants = sql_select_iterator ["\
      SELECT d.d_Level, d.CONNECT_BY_ISCYCLE, d.Owner, d.Name, d.Type, d.Referenced_Owner, d.Referenced_Name, d.Referenced_Link_Name, d.Referenced_Type, d.Dependency_Type,
             p.Grantee, p.Grantor, p.Privilege, p.Grantable, p.Hierarchy #{", p.Common" if get_db_version >= '12.1'},
             CASE WHEN u.UserName IS NOT NULL THEN 'USER'
             WHEN r.Role IS NOT NULL THEN 'ROLE'
             ELSE 'Unknown' END Grantee_Type
      FROM   (SELECT /*+ NO_MERGE */ Level d_Level, DECODE(CONNECT_BY_ISCYCLE, 1, 'YES') CONNECT_BY_ISCYCLE, d.*
              FROM   DBA_Dependencies d
              CONNECT BY NOCYCLE PRIOR Owner  = Referenced_Owner
                             AND PRIOR Name   = Referenced_Name
                             AND PRIOR Type   = Referenced_Type
              START WITH Referenced_Owner = ?
                     AND Referenced_Name  = ?
             ) d
      JOIN   DBA_Tab_Privs p ON p.Owner = d.Owner AND p.Table_Name = d.Name AND p.Type = d.Type
      LEFT OUTER JOIN DBA_Users u ON u.UserName = p.Grantee
      LEFT OUTER JOIN DBA_Roles r ON r.Role = p.Grantee
    ",  @owner, @object_name]
    render_partial
  end

  def list_plsql_description
    @owner                = params[:owner]
    @object_name          = params[:object_name]
    @object_type          = params[:object_type]
    @current_update_area  = params[:update_area]

    @dependencies = get_dependencies_count(@owner, @object_name, @object_type)
    @grants       = get_grant_count(@owner, @object_name)

    @attribs = sql_select_all ["SELECT o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Status FROM DBA_Objects o WHERE o.Owner = ? AND o.Object_Name = ? AND o.Object_Type = ?", @owner, @object_name, @object_type]

    @source = "CREATE OR REPLACE "
    sql_select_iterator(["SELECT Text FROM DBA_Source WHERE Owner=? AND Name=? AND Type = ? ORDER BY Line", @owner, @object_name, @object_type]).each do |r|
      @source << r.text
    end

    render_partial :list_plsql_description
  end

  def list_synonym
    @owner         = params[:owner]
    @object_name   = params[:object_name]
    @object_type   = params[:object_type]

    syn_data = sql_select_first_row ["SELECT * FROM DBA_Synonyms WHERE Owner = ? AND Synonym_Name = ?", @owner, @object_name]
    @result = "Is synonym for #{syn_data.table_owner}.#{syn_data.table_name}"
    @result << "@#{syn_data.db_link}" if syn_data.db_link

    @dependencies = get_dependencies_count(@owner, @object_name, @object_type)

    @attribs = sql_select_all ["SELECT o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Status FROM DBA_Objects o WHERE o.Owner = ? AND o.Object_Name = ? AND o.Object_Type = ?", @owner, @object_name, @object_type]

    render_partial :list_synonym
  end

  def list_cluster(owner, cluster_name)
    @owner        = owner
    @cluster_name = cluster_name

    @attribs = sql_select_all ["SELECT c.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Object_ID
                                FROM DBA_Clusters c
                                LEFT OUTER JOIN DBA_Objects o ON o.Owner = c.Owner AND o.Object_Name = c.Cluster_Name AND o.Object_Type = 'CLUSTER'
                                WHERE c.Owner = ? AND c.Cluster_Name = ?
                               ", @owner, @cluster_name]

    @tables = sql_select_one ['SELECT COUNT(*) FROM DBA_Tables WHERE Owner = ? AND Cluster_Name = ?', @owner, @cluster_name]

    @indexes = sql_select_one ['SELECT COUNT(*) FROM DBA_Indexes WHERE Table_Owner = ? AND Table_Name = ?', @owner, @cluster_name]

    render_partial :list_cluster
  end

  def list_recyclebin_description(owner, object_name, type)
    @owner        = owner
    @object_name  = object_name
    @type         = type

    @recyclebins = sql_select_all ["SELECT b.*,
                                           TO_DATE(CreateTime, 'YYYY-MM-DD HH24:MI:SS') Create_TS,
                                           TO_DATE(DropTime,   'YYYY-MM-DD HH24:MI:SS') Drop_TS,
                                           (SELECT SUM(Bytes)/(1024*1024)
                                            FROM   DBA_Segments s
                                            WHERE  s.Owner = b.Owner AND s.Segment_Name = b.Object_Name) Size_MB
                                    FROM   DBA_RecycleBin b
                                    WHERE  b.Owner = ? AND b.Object_Name = ? AND b.Type = ?
                                   ", owner, object_name, type]
    render_partial :list_recyclebin_description
  end

  def list_cluster_tables
    @owner        = params[:owner]
    @cluster_name = params[:cluster_name]

    @tables = sql_select_all ["SELECT t.* FROM DBA_Tables t WHERE t.Owner = ? AND t.Cluster_Name = ?", @owner, @cluster_name]

    render_partial :list_cluster_tables
  end

  def list_view_description
    @owner         = params[:owner]
    @object_name   = params[:object_name]
    @object_type   = params[:object_type]

    @dependencies = get_dependencies_count(@owner, @object_name, @object_type)
    @grants       = get_grant_count(@owner, @object_name)

    @attribs = sql_select_all ["SELECT o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, o.Status FROM DBA_Objects o WHERE o.Owner = ? AND o.Object_Name = ? AND o.Object_Type = ?", @owner, @object_name, @object_type]

    @view = sql_select_first_row ["SELECT * FROM DBA_Views WHERE Owner = ? AND View_Name = ?", @owner, @object_name]

    render_partial :list_view_description
  end

  def list_trigger_body
    @owner                = prepare_param(:owner)
    @trigger_name         = prepare_param(:trigger_name)
    @current_update_area  = params[:update_area]

    @body = sql_select_one ["\
      SELECT Trigger_Body
      FROM   DBA_Triggers
      WHERE  Owner = ?
      AND    Trigger_Name  = ?
      ", params[:owner], params[:trigger_name]]

    render_partial
  end

  def list_index_partitions
    @owner      = params[:owner]
    @index_name = params[:index_name]

    @partition_expression = get_index_partition_expression(@owner, @index_name)

    @partitions = sql_select_all ["\
      WITH Storage AS (SELECT /*+ NO_MERGE MATERIALIZE */   NVL(sp.Partition_Name, s.Partition_Name) Partition_Name, SUM(Bytes)/(1024*1024) MB, SUM(s.Blocks) Segment_Blocks, SUM(s.Extents) Extents
                      FROM DBA_Segments s
                      LEFT OUTER JOIN DBA_Ind_SubPartitions sp ON sp.Index_Owner = s.Owner AND sp.Index_Name = s.Segment_Name AND sp.SubPartition_Name = s.Partition_Name
                      WHERE s.Owner = ? AND s.Segment_Name = ?
                      GROUP BY NVL(sp.Partition_Name, s.Partition_Name)
                      )
      SELECT p.*, st.MB Size_MB, st.Segment_Blocks, st.Extents,
             o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS,
              sp.SubPartition_Count,
              SP_Status_Count,       SP_Status,
              SP_Compression_Count,  SP_Compression,
              SP_Tablespace_Count,   SP_Tablespace_Name,
              SP_Pct_Free_Count,     SP_Pct_Free,
              SP_Ini_Trans_Count,    SP_Ini_Trans,
              SP_Max_Trans_Count,    SP_Max_Trans,
              SP_Initial_Extent_Count,  SP_Initial_Extent,
              CASE WHEN Initial_Extent IS NOT NULL THEN Initial_Extent/1024 END Initial_Extent_KB
              #{", mi.GC_Mastering_Policy,  mi.Current_Master + 1  Current_Master,  mi.Previous_Master + 1  Previous_Master, mi.Remaster_Cnt" if PanoramaConnection.rac?}
      FROM DBA_Ind_Partitions p
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = p.Index_Owner AND o.Object_Name = p.Index_Name AND o.SubObject_Name = p.Partition_Name AND o.Object_Type = 'INDEX PARTITION'
      LEFT OUTER JOIN Storage st ON st.Partition_Name = p.Partition_Name
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Partition_Name, COUNT(*) SubPartition_Count,
                              COUNT(DISTINCT Status)          SP_Status_Count,          MIN(Status)           SP_Status,
                              COUNT(DISTINCT Compression)     SP_Compression_Count,     MIN(Compression)      SP_Compression,
                              COUNT(DISTINCT Tablespace_Name) SP_Tablespace_Count,      MIN(Tablespace_Name)  SP_Tablespace_Name,
                              COUNT(DISTINCT Pct_Free)        SP_Pct_Free_Count,        MIN(Pct_Free)         SP_Pct_Free,
                              COUNT(DISTINCT Ini_Trans)       SP_Ini_Trans_Count,       MIN(Ini_Trans)        SP_Ini_Trans,
                              COUNT(DISTINCT Max_Trans)       SP_Max_Trans_Count,       MIN(Max_Trans)        SP_Max_Trans,
                              COUNT(DISTINCT Initial_Extent)  SP_Initial_Extent_Count,  MIN(Initial_Extent)   SP_Initial_Extent
                       FROM   DBA_Ind_SubPartitions WHERE  Index_Owner = ? AND Index_Name = ?
                       GROUP BY Partition_Name
                      ) sp ON sp.Partition_Name = p.Partition_Name
   #{"LEFT OUTER JOIN V$GCSPFMASTER_INFO mi ON mi.Data_Object_ID = o.Data_Object_ID" if PanoramaConnection.rac?}
      WHERE p.Index_Owner = ? AND p.Index_Name = ?
      ", @owner, @index_name, @owner, @index_name, @owner, @index_name]
    @partitions.sort! {|a, b| b.high_value <=> a.high_value }

    @partitions.each do |p|
      if !p.subpartition_count.nil? && p.subpartition_count > 0
        p.status            = p.sp_status_count       == 1 ? p.sp_status          : "< #{p.sp_status_count} different >"                if p.sp_status_count      > 0
        p.compression       = p.sp_compression_count  == 1 ? p.sp_compression     : "< #{p.sp_compression_count} different >"           if p.sp_compression_count > 0
        p.tablespace_name   = p.sp_tablespace_count   == 1 ? p.sp_tablespace_name : "< #{p.sp_tablespace_count} different >"            if p.sp_tablespace_count  > 0
        p.pct_free          = p.sp_pct_free_count     == 1 ? p.sp_pct_free        : "< #{p.sp_pct_free_count} different >"              if p.sp_pct_free_count    > 0
        p.ini_trans         = p.sp_ini_trans_count    == 1 ? p.sp_ini_trans       : "< #{p.sp_ini_trans_count} different >"             if p.sp_ini_trans_count   > 0
        p.max_trans         = p.sp_max_trans_count    == 1 ? p.sp_max_trans       : "< #{p.sp_max_trans_count} different >"             if p.sp_max_trans_count   > 0
        p.initial_extent_kb = p.sp_initial_extent_count == 1 ? fn(p.sp_initial_extent/1024)  : "< #{p.sp_initial_extent_count} different >"        if p.sp_initial_extent_count > 0
      end
    end

    render_partial
  end


  def list_index_subpartitions
    @owner      = params[:owner]
    @index_name = params[:index_name]
    @partition_name = params[:partition_name]

    @partition_expression = get_index_partition_expression(@owner, @index_name)

    @subpartitions = sql_select_all ["\
      SELECT sp.*, s.Bytes/(1024*1024) Size_MB, s.Blocks Segment_Blocks, s.Extents,
             o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS, p.High_Value Partition_High_Value
              #{", mi.GC_Mastering_Policy,  mi.Current_Master + 1  Current_Master,  mi.Previous_Master + 1  Previous_Master, mi.Remaster_Cnt" if PanoramaConnection.rac?}
      FROM DBA_Ind_SubPartitions sp
      JOIN DBA_Ind_Partitions p ON p.Index_Owner = sp.Index_Owner AND p.Index_Name = sp.Index_Name AND p.Partition_Name = sp.Partition_Name
      LEFT OUTER JOIN DBA_Segments s ON s.Owner = sp.Index_Owner AND s.Segment_Name = sp.Index_Name AND s.Partition_Name = sp.SubPartition_Name
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = sp.Index_Owner AND o.Object_Name = sp.Index_Name AND o.SubObject_Name = sp.SubPartition_Name AND o.Object_Type = 'INDEX SUBPARTITION'
   #{"LEFT OUTER JOIN V$GCSPFMASTER_INFO mi ON mi.Data_Object_ID = o.Data_Object_ID" if PanoramaConnection.rac?}
      WHERE sp.Index_Owner = ? AND sp.Index_Name = ?
      #{" AND sp.Partition_Name = ?" if @partition_name}
      ", @owner, @index_name, @partition_name]
    @subpartitions.sort! {|a, b| b.high_value <=> a.high_value }

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
      SELECT /*+ Panorama Ramm */ l.*,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner = l.Owner AND s.Segment_Name = l.Segment_Name) Size_MB,
             (SELECT SUM(Blocks)            FROM DBA_Segments s WHERE s.Owner = l.Owner AND s.Segment_Name = l.Segment_Name) Blocks,
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

  def show_audit_rules
    @audits         = sql_select_all "SELECT * FROM DBA_Stmt_Audit_Opts ORDER BY Audit_Option"
    @obj_audit_opts = sql_select_all "SELECT * FROM DBA_Obj_Audit_Opts ORDER BY Owner, Object_Name"
    @options        = sql_select_all "SELECT * FROM gv$Option WHERE Parameter = 'Unified Auditing' ORDER BY Inst_ID"
    @policies       = sql_select_iterator "SELECT * from DBA_Audit_Policies"
    begin
      @config_params = sql_select_all "SELECT * FROM DBA_Audit_Mgmt_Config_Params ORDER BY Audit_Trail, Parameter_Name"
    rescue Exception => e
      if e.message['ORA-00942']
        @config_params = []
        add_statusbar_message "Access on DBA_Audit_Mgmt_Config_Params not allowed"
      else
        raise
      end
    end
    render_partial
  end

  def show_audit_trail
    render_partial
  end

  def show_unified_audit_trail
    render_partial
  end

  def list_audit_trail
    @instance       = prepare_param_instance
    @audit_type     = prepare_param :audit_type
    @session_id     = prepare_param :session_id
    @os_user        = prepare_param :os_user
    @db_user        = prepare_param :db_user
    @machine        = prepare_param :machine
    @object_name    = prepare_param :object_name
    @statement_type = prepare_param :statement_type
    where_string = ""
    where_values = []

    if params[:time_selection_start] && params[:time_selection_end]
      save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
      where_string << " AND Extended_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND Extended_Timestamp <  TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')"
      where_values << @time_selection_start
      where_values << @time_selection_end
    end

    if @instance
      # Instance_Number is 0 in DBA_Audit_Trail for non-RAC systems
      where_string << " AND DECODE(Instance_Number, 0, 1, Instance_Number) =?"
      where_values << @instance
    end

    if @audit_type
      where_string << " AND Audit_Type=?"
      where_values << @audit_type
    end

    if @session_id
      where_string << " AND Session_ID=?"
      where_values << @session_id
    end

    if @os_user
      where_string << " AND UPPER(OS_User) LIKE UPPER('%'||?||'%')"
      where_values << @os_user
    end

    if @db_user
      where_string << " AND UPPER(DB_User) LIKE UPPER('%'||?||'%')"
      where_values << @db_user
    end

    if @machine
      where_string << " AND UPPER(UserHost) LIKE UPPER('%'||?||'%')"
      where_values << @machine
    end

    if @object_name
      where_string << " AND UPPER(Object_Name) LIKE UPPER('%'||?||'%')"
      where_values << @object_name
    end

    if @statement_type
      where_string << " AND UPPER(statement_type) LIKE UPPER('%'||?||'%')"
      where_values << @statement_type
    end

    if params[:grouping] && params[:grouping] != "none"
      list_audit_trail_grouping(params[:grouping], where_string, where_values, params[:top_x].to_i)
    else
      @audits = sql_select_iterator ["\
                     SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ a.*,
                            RAWTOHEX(a.TransactionID) TransactionID_Hex
                     FROM   DBA_Common_Audit_Trail a
                     WHERE  1=1 #{where_string}
                     ORDER BY Extended_Timestamp
                    "].concat(where_values)

      render_partial :list_audit_trail
    end
  end

  # Gruppierte Ausgabe der Audit-Trail-Info
  def list_audit_trail_grouping(grouping, where_string, where_values, top_x)
    @grouping = grouping
    @top_x    = top_x

    group_time_sql = "TRUNC(Extended_Timestamp, '#{grouping}')"
    group_time_sql = "CAST (Extended_Timestamp AS DATE)" if grouping == 'SS'

    audits = sql_select_all ["\
                   SELECT /*+ FIRST_ROWS(1) Panorama Ramm */ *
                   FROM   (SELECT #{group_time_sql} Begin_Timestamp,
                                  MAX(Extended_Timestamp)+1/1440 Max_Timestamp,  -- auf naechste ganze Minute aufgerundet
                                  UserHost, OS_User, DB_User, Statement_Type,
                                  COUNT(*)         Audits
                                  FROM   DBA_Common_Audit_Trail
                                  WHERE  1=1 #{where_string}
                                  GROUP BY #{group_time_sql}, UserHost, OS_User, DB_User, Statement_Type
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

        rec[:os_users][a.os_user] = (rec[:os_users][a.os_user] ||=0) + a.audits
        os_users[a.os_user] = (os_users[a.os_user] ||= 0) + a.audits

        rec[:db_users][a.db_user] = (rec[:db_users][a.db_user] ||=0) + a.audits
        db_users[a.db_user] = (db_users[a.db_user] ||= 0) + a.audits

        rec[:actions][a.statement_type] = (rec[:actions][a.statement_type] ||=0) + a.audits
        actions[a.statement_type] = (actions[a.statement_type] ||= 0) + a.audits

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
      @actions << { :statement_type=>key, :audits=>value}
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
    @histogram    = params[:histogram]

    interpreted_endpoint_value = 'NULL'
    interpreted_endpoint_value = "TO_CHAR(TO_DATE(TRUNC(endpoint_value),'J')+(ENDPOINT_VALUE-TRUNC(ENDPOINT_VALUE)), '#{sql_datetime_second_mask}')" if @data_type == 'DATE'
    interpreted_endpoint_value = "TO_CHAR(TO_DATE(TRUNC(endpoint_value),'J')+(ENDPOINT_VALUE-TRUNC(ENDPOINT_VALUE)), '#{sql_datetime_second_mask}')" if @data_type['TIMESTAMP']
    # Interpret low and high value if there is no histogram for char
    interpreted_endpoint_value = "(SELECT  DECODE(h.Endpoint_Number, 0, UTL_I18N.RAW_TO_CHAR(c.Low_Value), UTL_I18N.RAW_TO_CHAR(c.High_Value)) FROM DBA_Tab_Columns c WHERE c.Owner = h.Owner AND c.Table_Name = h.Table_Name AND c.Column_Name = h.Column_Name)" if @histogram == 'NONE' && ['CHAR', 'VARCHAR2'].include?(@data_type)
    interpreted_endpoint_value = "utl_raw.cast_to_varchar2(substr(lpad(to_char(endpoint_value,'fmxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),30,'0'),1,14))" if @histogram != 'NONE' && @data_type == ['CHAR']

    @histograms = sql_select_all ["SELECT h.*,
                                          NVL(Endpoint_Number - LAG(Endpoint_Number) OVER (ORDER BY Endpoint_Number), Endpoint_Number) * #{@num_rows} / MAX(Endpoint_Number) OVER () Num_Rows,
                                          #{interpreted_endpoint_value} Interpreted_Endpoint_Value
                                   FROM   DBA_Tab_Histograms h
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

  def list_gather_table_historic
    @owner              = params[:owner]
    @table_name         = params[:table_name]
    @partition_name     = prepare_param :partition_name

    @operations = analyze_operations(@owner, @table_name, @partition_name)

    where_string = ''
    where_values = []

    if @partition_name
      where_string << " AND o.Subobject_Name = ?"
      where_values << @partition_name
    else
      where_string << " AND SubObject_Name IS NULL"
    end
    @tab_history = sql_select_all ["SELECT t.*, o.Subobject_Name
                                    FROM   DBA_Objects o
                                    JOIN   sys.WRI$_OPTSTAT_TAB_HISTORY t ON t.Obj# = o.Object_ID
                                    WHERE  o.Owner = ? AND o.Object_Name = ? #{where_string}
                                    ORDER BY t.AnalyzeTime DESC
                                   ", @owner, @table_name].concat(where_values)

    if get_db_version >= '11.1'
      @extensions     = sql_select_all ["SELECT * FROM DBA_Stat_Extensions WHERE Owner = ? AND Table_Name = ?", @owner, @table_name]

      @prefs = sql_select_all ["\
        WITH prefs AS (SELECT 'APPROXIMATE_NDV_ALGORITHM' Name, 'REPEAT OR HYPERLOGLOG' Default_Value FROM DUAL UNION ALL
                       SELECT 'AUTO_STAT_EXTENSIONS',           'OFF'                                 FROM Dual UNION ALL
                       SELECT 'AUTO_TASK_STATUS',               'OFF'                                 FROM Dual UNION ALL
                       SELECT 'AUTO_TASK_MAX_RUN_TIME',         '3600'                                FROM Dual UNION ALL
                       SELECT 'AUTO_TASK_INTERVAL',             '900'                                 FROM Dual UNION ALL
                       SELECT 'AUTOSTATS_TARGET',               'AUTO'                                FROM Dual UNION ALL
                       SELECT 'CASCADE',                        'DBMS_STATS.AUTO_CASCADE'             FROM Dual UNION ALL
                       SELECT 'CONCURRENT',                     'OFF'                                 FROM Dual UNION ALL
                       SELECT 'DEGREE',                         'NULL'                                FROM Dual UNION ALL
                       SELECT 'ESTIMATE_PERCENT',               'DBMS_STATS.AUTO_SAMPLE_SIZE'         FROM Dual UNION ALL
                       SELECT 'GLOBAL_TEMP_TABLE_STATS',        'SESSION'                             FROM Dual UNION ALL
                       SELECT 'GRANULARITY',                    'AUTO'                                FROM Dual UNION ALL
                       SELECT 'INCREMENTAL',                    'FALSE'                               FROM Dual UNION ALL
                       SELECT 'INCREMENTAL_LEVEL',              'PARTITION'                           FROM Dual UNION ALL
                       SELECT 'INCREMENTAL_STALENESS',          'ALLOW_MIXED_FORMAT'                  FROM Dual UNION ALL
                       SELECT 'METHOD_OPT',                     'FOR ALL COLUMNS SIZE AUTO'           FROM Dual UNION ALL
                       SELECT 'NO_INVALIDATE',                  'DBMS_STATS.AUTO_INVALIDATE'          FROM Dual UNION ALL
                       SELECT 'OPTIONS',                        'GATHER'                              FROM Dual UNION ALL
                       SELECT 'PREFERENCE_OVERRIDES_PARAMETER', 'FALSE'                               FROM Dual UNION ALL
                       SELECT 'PUBLISH',                        'TRUE'                                FROM Dual UNION ALL
                       SELECT 'STALE_PERCENT',                  '10'                                  FROM Dual UNION ALL
                       SELECT 'STAT_CATEGORY',                  'OBJECT_STATS, REALTIME_STATS'        FROM Dual UNION ALL
                       SELECT 'TABLE_CACHED_BLOCKS',            '1'                                   FROM Dual UNION ALL
                       SELECT 'WAIT_TIME_TO_UPDATE_STATS',      '15'                                  FROM DUAL
                      )
        SELECT *
        FROM   (
                SELECT p.Name, p.Default_Value, DBMS_Stats.Get_Prefs(p.Name, ?, ?) Value, DECODE(tp.Preference_Name, NULL, 'Y', 'N') Global
                FROM   prefs p
                LEFT OUTER JOIN DBA_Tab_Stat_Prefs tp ON tp.Owner = ? AND tp.Table_Name = ? AND tp.Preference_Name = p.Name
               )
        WHERE  Value != Default_Value
      ", @owner, @table_name, @owner, @table_name]
    end

    render_partial
  end

  def list_gather_index_historic
    @owner      = params[:owner]
    @index_name = params[:index_name]
    @partition_name = prepare_param :partition_name


    @operations = analyze_operations(@owner, @index_name, @partition_name)

    where_string = ''
    where_values = []

    if @partition_name
      where_string << " AND SubObject_Name = ?"
      where_values << @partition_name
    else
      where_string << " AND SubObject_Name IS NULL"
    end
    @ind_history = sql_select_all ["SELECT t.*, o.Subobject_Name
                                    FROM   DBA_Objects o
                                    JOIN   sys.WRI$_OPTSTAT_Ind_HISTORY t ON t.Obj# = o.Object_ID
                                    WHERE  o.Owner = ? AND o.Object_Name = ? #{where_string}
                                    ORDER BY t.AnalyzeTime DESC
                                   ", @owner, @index_name].concat(where_values)

    render_partial
  end

  def list_dbms_metadata_get_ddl
    @owner       = params[:owner]
    @table_name  = params[:table_name]
    @object_type = params[:object_type]
    @object_type = case @object_type
                     when 'MATERIALIZED VIEW' then 'MATERIALIZED_VIEW'
                     else
                       @object_type
                   end

    begin
      ddl = sql_select_one ["SELECT DBMS_METADATA.GET_DDL(object_type => ?, schema => ?, name => ?) FROM DUAL", @object_type, @owner, @table_name]
      ddl << ";\n"

      indexes = sql_select_all ["SELECT Owner, Index_Name FROM DBA_Indexes WHERE Table_Owner = ? AND Table_Name = ? AND Index_Type NOT IN ('LOB')", @owner, @table_name]

      indexes.each do |i|
        index_ddl = sql_select_one ["SELECT DBMS_METADATA.GET_DDL(object_type => 'INDEX', schema => ?, name => ?) FROM DUAL", i.owner, i.index_name]
        ddl << "\n#{index_ddl}"
        ddl << ";\n"
      end
    rescue Exception => e
      message = e.message
      message << "\n\nPossible reason: You need to have SELECT_CATALOG_ROLE to get results from DBMS_METADATA.GET_DDL"
      raise message
    end

    respond_to do |format|
      format.html {render :html => "<h3>DDL for #{@object_type} #{@owner}.#{@table_name} generated by DBMS_METADATA.GET_DDL</h3>#{render_code_mirror(ddl)}".html_safe }
    end

  end

  def invalid_objects
    @objects = sql_select_iterator("SELECT o.*,
                                           TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_Time
                                    FROM   DBA_Objects o
                                    WHERE Status != 'VALID'
                                    ORDER BY Last_DDL_Time DESC
    ")

    @indexes = sql_select_iterator("\
      SELECT i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, NULL Partition_Name, i.Status, o.Object_Type,
             o.Object_ID, o.Data_Object_ID, o.Created, o.Last_DDL_Time,
             TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_Time
      FROM   DBA_Indexes i
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.SubObject_Name IS NULL
      WHERE i.Status NOT IN ('VALID', 'N/A', 'USABLE')
      UNION ALL
      SELECT ip.Index_Owner, ip.Index_Name, i.Table_Owner, i.Table_Name, ip. Partition_Name, ip.Status, o.Object_Type,
             o.Object_ID, o.Data_Object_ID, o.Created, o.Last_DDL_Time,
             TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_Time
      FROM   DBA_Ind_Partitions ip
      JOIN   DBA_Indexes i ON i.Owner = ip.Index_Owner AND i.Index_Name = ip.Index_Name
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.SubObject_Name = ip.Partition_Name
      WHERE ip.Status NOT IN ('VALID', 'N/A', 'USABLE')
      UNION ALL
      SELECT ip.Index_Owner, ip.Index_Name, i.Table_Owner, i.Table_Name, ip. Partition_Name, ip.Status, o.Object_Type,
             o.Object_ID, o.Data_Object_ID, o.Created, o.Last_DDL_Time,
             TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Last_Spec_Time
      FROM   DBA_Ind_SubPartitions ip
      JOIN   DBA_Indexes i ON i.Owner = ip.Index_Owner AND i.Index_Name = ip.Index_Name
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.SubObject_Name = ip.Partition_Name
      WHERE ip.Status NOT IN ('VALID', 'N/A', 'USABLE')
")
    render_partial
  end

  def list_space_usage
    @owner          = prepare_param(:owner)
    @segment_name   = prepare_param(:segment_name)
    @partition_name = prepare_param(:partition_name)

    @segment_type = sql_select_one ["SELECT DECODE(Segment_Type,
                                              'LOBSEGMENT',       'LOB',
                                              Segment_Type
                                            )
                                     FROM   DBA_Segments
                                     WHERE  Owner        = ?
                                     AND    Segment_Name = ?
                                     #{" AND Partition_Name = ? " if @partition_name}
                                     AND    RowNum < 2 /* List only one record */
                                    ",
                                    @owner, @segment_name].concat(@partition_name ? [@partition_name] : [])
    show_popup_message "Object does not exists in DBA_Segments for Owner = '#{@owner}', Segment_Name = '#{@segment_name}', Partition_Name = '#{@partition_name}'" if @segment_type.nil?

    case @segment_type
    when 'LOB', 'LOB PARTITION', 'LOB SUBPARTITION' then
      securefile = sql_select_one ["SELECT Securefile FROM DBA_Lobs WHERE Owner = ? AND Segment_Name = ?", @owner, @segment_name]
      show_popup_message "Object does not exists in DBA_Lobs for Owner = '#{@owner}', Segment_Name = '#{@segment_name}'" if securefile.nil?
      if securefile == 'NO'
        list_space_usage_default
      else
        list_space_usage_securefile
      end

      # check for securefile
    else
      list_space_usage_default
    end
  end

  private
  def list_space_usage_default
    @result = []


    segments = sql_select_all ["SELECT Partition_Name
                               FROM   DBA_Segments
                               WHERE  Owner        = ?
                               AND    Segment_Name = ?
                               #{" AND Partition_Name = ? " if @partition_name}
                              ",
                              @owner, @segment_name].concat(@partition_name ? [@partition_name] : [])

    segments.each do |segment|
      pct_free = nil                                                            # Default
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Tables             WHERE Owner = ?       AND Table_Name = ?",                            @owner, @segment_name]                              if @segment_type == 'TABLE'
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Tab_Partitions     WHERE Table_Owner = ? AND Table_Name = ? AND Partition_Name = ?",     @owner, @segment_name, segment.partition_name]      if @segment_type == 'TABLE PARTITION'
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Tab_SubPartitions  WHERE Table_Owner = ? AND Table_Name = ? AND SubPartition_Name = ?",  @owner, @segment_name, segment.partition_name]      if @segment_type == 'TABLE SUBPARTITION'
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Indexes            WHERE Owner = ?       AND Index_Name = ?",                            @owner, @segment_name]                              if @segment_type == 'INDEX'
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Ind_Partitions     WHERE Index_Owner = ? AND Index_Name = ? AND Partition_Name = ?",     @owner, @segment_name, segment.partition_name]      if @segment_type == 'INDEX PARTITION'
      pct_free = sql_select_one ["SELECT Pct_Free FROM DBA_Ind_SubPartitions  WHERE Index_Owner = ? AND Index_Name = ? AND SubPartition_Name = ?",  @owner, @segment_name, segment.partition_name]      if @segment_type == 'INDEX SUBPARTITION'


      connection = PanoramaConnection.get_jdbc_raw_connection
      cb = connection.prepareCall("CALL DBMS_SPACE.SPACE_USAGE(
                                       segment_owner        => ?,
                                       segment_name         => ?,
                                       segment_type         => ?,
                                       unformatted_blocks   => ?,
                                       unformatted_bytes    => ?,
                                       fs1_blocks           => ?,
                                       fs1_bytes            => ?,
                                       fs2_blocks           => ?,
                                       fs2_bytes            => ?,
                                       fs3_blocks           => ?,
                                       fs3_bytes            => ?,
                                       fs4_blocks           => ?,
                                       fs4_bytes            => ?,
                                       full_blocks          => ?,
                                       full_bytes           => ?
                                       #{", partition_name       => ?" if segment.partition_name}
                                     )")


      cb.setString(1, @owner)
      cb.setString(2, @segment_name)
      cb.setString(3, @segment_type)
      cb.registerOutParameter(4,  java.sql.Types::DECIMAL)    # unformatted_blocks
      cb.registerOutParameter(5,  java.sql.Types::DECIMAL)    # unformatted_bytes
      cb.registerOutParameter(6,  java.sql.Types::DECIMAL)    # fs1_blocks
      cb.registerOutParameter(7,  java.sql.Types::DECIMAL)    # fs1_bytes
      cb.registerOutParameter(8,  java.sql.Types::DECIMAL)    # fs2_blocks
      cb.registerOutParameter(9,  java.sql.Types::DECIMAL)    # fs2_bytes
      cb.registerOutParameter(10, java.sql.Types::DECIMAL)    # fs3_blocks
      cb.registerOutParameter(11, java.sql.Types::DECIMAL)    # fs3_bytes
      cb.registerOutParameter(12, java.sql.Types::DECIMAL)    # fs4_blocks
      cb.registerOutParameter(13, java.sql.Types::DECIMAL)    # fs4_bytes
      cb.registerOutParameter(14, java.sql.Types::DECIMAL)    # full_blocks
      cb.registerOutParameter(15, java.sql.Types::DECIMAL)    # full_bytes
      cb.setString(16, segment.partition_name)  if segment.partition_name

      cb.executeQuery();

      @result << {
          partition_name:     segment.partition_name,
          unformatted_blocks: BigDecimal(cb.getBigDecimal(4).to_s),
          unformatted_bytes:  BigDecimal(cb.getBigDecimal(5).to_s),
          fs1_blocks:         BigDecimal(cb.getBigDecimal(6).to_s),
          fs1_bytes:          BigDecimal(cb.getBigDecimal(7).to_s),
          fs2_blocks:         BigDecimal(cb.getBigDecimal(8).to_s),
          fs2_bytes:          BigDecimal(cb.getBigDecimal(9).to_s),
          fs3_blocks:         BigDecimal(cb.getBigDecimal(10).to_s),
          fs3_bytes:          BigDecimal(cb.getBigDecimal(11).to_s),
          fs4_blocks:         BigDecimal(cb.getBigDecimal(12).to_s),
          fs4_bytes:          BigDecimal(cb.getBigDecimal(13).to_s),
          full_blocks:        BigDecimal(cb.getBigDecimal(14).to_s),
          full_bytes:         BigDecimal(cb.getBigDecimal(15).to_s),
          pct_free:           pct_free
      }.extend(SelectHashHelper)

    end


    render_partial :list_space_usage_default
  rescue Exception => e
    if e.message['ORA-01031']
      show_popup_message "You need the ANALYZE privilege on #{@owner}.#{@segment_name} to call DBMS_SPACE.SPACE_USAGE\n\n#{e.message}"
    else
      log_exception_backtrace(e)
      raise e
    end
  end

  def list_space_usage_securefile
    @result = []


    segments = sql_select_all ["SELECT Partition_Name
                               FROM   DBA_Segments
                               WHERE  Owner        = ?
                               AND    Segment_Name = ?
                               #{" AND Partition_Name = ? " if @partition_name}
                               ",
                               @owner, @segment_name].concat(@partition_name ? [@partition_name] : [])

    segments.each do |segment|
      connection = PanoramaConnection.get_jdbc_raw_connection
      cb = connection.prepareCall("CALL DBMS_SPACE.SPACE_USAGE(
                                       segment_owner        => ?,
                                       segment_name         => ?,
                                       segment_type         => ?,
                                       segment_size_blocks  => ?,
                                       segment_size_bytes   => ?,
                                       used_blocks          => ?,
                                       used_bytes           => ?,
                                       expired_blocks       => ?,
                                       expired_bytes        => ?,
                                       unexpired_blocks     => ?,
                                       unexpired_bytes      => ?
                                       #{", partition_name       => ?" if segment.partition_name}
                                     )")


      cb.setString(1, @owner)
      cb.setString(2, @segment_name)
      cb.setString(3, @segment_type)
      cb.registerOutParameter(4,  java.sql.Types::DECIMAL)    # segment_size_blocks
      cb.registerOutParameter(5,  java.sql.Types::DECIMAL)    # segment_size_bytes
      cb.registerOutParameter(6,  java.sql.Types::DECIMAL)    # used_blocks
      cb.registerOutParameter(7,  java.sql.Types::DECIMAL)    # used_bytes
      cb.registerOutParameter(8,  java.sql.Types::DECIMAL)    # expired_blocks
      cb.registerOutParameter(9,  java.sql.Types::DECIMAL)    # expired_bytes
      cb.registerOutParameter(10, java.sql.Types::DECIMAL)    # unexpired_blocks
      cb.registerOutParameter(11, java.sql.Types::DECIMAL)    # unexpired_bytes
      cb.setString(12, segment.partition_name)  if segment.partition_name

      cb.executeQuery();

      @result << {
          partition_name:       segment.partition_name,
          segment_size_blocks:  BigDecimal(cb.getBigDecimal(4).to_s),
          segment_size_bytes:   BigDecimal(cb.getBigDecimal(5).to_s),
          used_blocks:          BigDecimal(cb.getBigDecimal(6).to_s),
          used_bytes:           BigDecimal(cb.getBigDecimal(7).to_s),
          expired_blocks:       BigDecimal(cb.getBigDecimal(8).to_s),
          expired_bytes:        BigDecimal(cb.getBigDecimal(9).to_s),
          unexpired_blocks:     BigDecimal(cb.getBigDecimal(10).to_s),
          unexpired_bytes:      BigDecimal(cb.getBigDecimal(11).to_s),
      }.extend(SelectHashHelper)

    end


    render_partial :list_space_usage_securefile
  rescue Exception => e
    if e.message['ORA-01031']
      show_popup_message "You need the ANALYZE privilege on #{@owner}.#{@segment_name} to call DBMS_SPACE.SPACE_USAGE\n\n#{e.message}"
    else
      log_exception_backtrace(e)
      raise e
    end
  end

  private
  def analyze_operations(owner, object_name, partition_name)
    where_string = ''
    where_values = []

    if partition_name
      where_string << " AND Partition_Name = ?"
      where_values << partition_name
    else
      where_string << " AND Partition_Name IS NULL"
    end

    sql_select_all ["SELECT o.*,
                            EXTRACT(HOUR FROM End_Time - Start_Time)*60*24 + EXTRACT(MINUTE FROM End_Time - Start_Time)*60 + EXTRACT(SECOND FROM End_Time - Start_Time) Duration
                    FROM   (SELECT SUBSTR(sTarget, 1, INSTR(sTarget, '.')-1) Owner,
                                   CASE WHEN INSTR(sTarget, '.', 1, 2) = 0
                                   THEN
                                   SUBSTR(sTarget, INSTR(sTarget, '.')+1)
                                   ELSE
                                   SUBSTR(sTarget, INSTR(sTarget, '.')+1, INSTR(sTarget, '.', 1, 2) - INSTR(sTarget, '.')-1)
                                   END Object_Name,
                                   CASE WHEN INSTR(sTarget, '.', 1, 2) > 0 THEN
                                   SUBSTR(sTarget, INSTR(sTarget, '.', 1, 2)+1)
                                   END Partition_Name,
                                   o.*
                            FROM   (SELECT o.*, REPLACE(Target, '\"', '') STarget /* Target has double quotes starting with 19c */
                                    FROM   sys.WRI$_OPTSTAT_OPR o
                                   ) o
                           ) o
                    WHERE  Owner = ? AND Object_Name = ? #{where_string}
                    ORDER BY Start_Time DESC
                   ", owner, object_name].concat(where_values)
  end

end