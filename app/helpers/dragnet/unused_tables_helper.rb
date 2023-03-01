# encoding: utf-8
module Dragnet::UnusedTablesHelper

  private

  def unused_tables
    [
        {
            :name  => t(:dragnet_helper_64_name, :default => 'Detection of tables never accessed by SELECT statements'),
            :desc  => t(:dragnet_helper_64_desc, :default =>'Tables never used for selections may be questioned for their right to exist.
This includes tables that were written, but never read.
This selections scans SGA as well as AWR history.
'),
            :sql=> "WITH Days AS (SELECT ? backward FROM DUAL),
                         Tab_Modifications AS (SELECT /*+ NO_MERGE MATERIALIZE */ * FROM   DBA_Tab_Modifications),
                         Tabs_Inds AS (SELECT /*+ NO_MERGE MATERIALIZE */ 'TABLE' Object_Type, Owner, Table_Name Object_Name, Last_Analyzed, Num_Rows
                                       FROM   DBA_Tables
                                       WHERE  IOT_TYPE IS NULL AND Temporary='N'
                                       AND    Owner NOT IN (#{system_schema_subselect})
                                       UNION ALL
                                       SELECT /*+ NO_MERGE */ 'INDEX' Object_Type, Owner, Index_Name Object_Name, Last_Analyzed, Num_Rows
                                       FROM   DBA_Indexes
                                       WHERE  Index_Type = 'IOT - TOP'
                                       AND    Owner NOT IN (#{system_schema_subselect})
                                      ),
                         Hist_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ DISTINCT DBID, SQL_ID, Plan_Hash_Value,  Object_Type, Object_Owner, Object_Name
                                        FROM   DBA_Hist_SQL_Plan
                                        WHERE Object_Type IS NOT NULL AND Object_Owner IS NOT NULL AND Object_Name IS NOT NULL
                                       ),
                         SGA_Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ DISTINCT Inst_ID, SQL_ID, Plan_Hash_Value,  Object_Type, Object_Owner, Object_Name
                                       FROM  gv$SQL_Plan
                                       WHERE Object_Type IS NOT NULL AND Object_Owner IS NOT NULL AND Object_Name IS NOT NULL
                                      ),
                         SQL_Stat AS (SELECT /*+ NO_MERGE MATERIALIZE */ ss.DBID, s.SQL_ID, s.Plan_Hash_Value
                                      FROM   DBA_Hist_SQLStat s
                                      JOIN   DBA_Hist_SnapShot ss  ON  ss.DBID      = s.DBID
                                                                   AND ss.Snap_ID = s.Snap_ID
                                                                   AND ss.Instance_Number = s.Instance_Number
                                      WHERE  ss.Begin_Interval_Time > SYSDATE - (SELECT Backward FROM Days)
                                     ),
                         Used AS ( SELECT /*+ NO_MERGE MATERIALIZE */
                                          DISTINCT Object_Type, Object_Owner, Object_Name
                                   FROM   (SELECT p.Object_Type, p.Object_Owner, p.Object_Name
                                           FROM   Hist_Plans p
                                           JOIN   SQL_Stat s   ON  s.DBID            = p.DBID
                                                               AND s.SQL_ID          = p.SQL_ID
                                                               AND s.Plan_Hash_Value = p.Plan_Hash_Value
                                           UNION ALL
                                           SELECT /*+ NO_MERGE */ p.Object_Type, p.Object_Owner, p.Object_Name
                                           FROM   SGA_Plans p
                                           JOIN   gv$SQLArea s ON s.Inst_ID=p.Inst_ID AND s.SQL_ID=p.SQL_ID AND s.Plan_Hash_Value=p.Plan_Hash_Value
                                           WHERE  s.Last_Active_Time > SYSDATE-(SELECT Backward FROM Days)
                                           AND    s.SQL_FullText NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                           AND    s.Command_Type = 3 /* SELECT */
                                          )
                                 )
                    SELECT /* DB-Tools Ramm not used tables */ o.*, sz.MBytes, ob.Created, ob.Last_DDL_Time, tm.Timestamp Last_DML_Timestamp, tm.Inserts, tm.Updates, tm.Deletes
                    FROM Tabs_Inds o
                    LEFT OUTER JOIN used ON used.Object_Owner = o.Owner AND used.Object_Name = o.Object_Name
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Segment_Name, Owner, SUM(bytes)/(1024*1024) MBytes
                                     FROM   DBA_SEGMENTS
                                     WHERE  Owner NOT IN (#{system_schema_subselect})
                                     GROUP BY Segment_Name, Owner
                                    ) sz ON sz.SEGMENT_NAME = o.Object_Name AND sz.Owner = o.Owner
                    LEFT OUTER JOIN DBA_Objects ob ON ob.Owner = o.Owner AND ob.Object_Name = o.Object_Name AND ob.SubObject_Name IS NULL
                    LEFT OUTER JOIN Tab_Modifications tm ON tm.Table_Owner = o.Owner AND tm.Table_Name = o.Object_Name AND tm.Partition_Name IS NULL AND tm.SubPartition_Name IS NULL
                    WHERE  used.Object_Owner IS NULL
                    AND    used.Object_Name IS NULL
                    ORDER BY sz.MBytes DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_64_param_1_name, :default=>'Number of days backward in AWR-Historie for SQL'), :size=>8, :default=>2, :title=> t(:dragnet_helper_64_param_1_hint, :default=>'Number of days backward for evaluation of AWR-history regarding usage of table in execution plans of SQL-statements')},
            ]
        },
        {
            :name  => t(:dragnet_helper_65_name, :default=>'Missing housekeeping for mass data'),
            :desc  => t(:dragnet_helper_65_desc, :default=>'For many constellations it is essential to remove not productive used aged data from the system m System.
If last analyze table was far enough in history this selection may help to detect gaps in housekeeping.
Stated here are inserts and updates since last GATHER_TABLE_STATS for tables without any delete operations.
'),
            :sql=> "SELECT /* DB-Tools Ramm Housekeeping*/
                             m.Table_Owner, m.Table_Name, t.Num_Rows, s.Size_MB, m.TimeStamp Last_DML_Timestamp, t.Last_analyzed, t.Monitoring,
                             ROUND(SYSDATE - t.Last_Analyzed, 2) Days_After_Analyze,
                             m.Inserts, ROUND(m.Inserts/(SYSDATE - t.Last_Analyzed)) Inserts_Per_Day, m.Updates, ROUND(m.Updates/(SYSDATE - t.Last_Analyzed)) Updates_Per_Day, m.Deletes, m.Truncated, m.Drop_Segments
                      FROM   (SELECT Table_Owner, Table_Name, MAX(Timestamp) Timestamp,
                                     SUM(Inserts) Inserts, SUM(Updates) Updates, SUM(Deletes) Deletes,
                                     MAX(Truncated) Truncated, SUM(Drop_Segments) Drop_Segments
                              FROM sys.DBA_Tab_Modifications
                              GROUP BY Table_Owner, Table_Name
                             ) m
                      JOIN   DBA_Tables t ON t.Owner = m.Table_Owner AND t.Table_Name = m.Table_Name
                      LEFT OUTER JOIN (SELECT Owner, Segment_Name, ROUND(SUM(Bytes)/(1024*1024),1) Size_MB
                                       FROM DBA_Segments s
                                       WHERE Owner NOT IN (#{system_schema_subselect})
                                       GROUP BY Owner, Segment_Name
                                      ) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
                      WHERE m.Deletes = 0 AND m.Truncated = 'NO'
                      AND   t.Last_Analyzed < SYSDATE    /* avoid division by zero */
                      AND   t.Num_Rows > ?
                      AND   SYSDATE - t.Last_Analyzed > ?
                      ORDER BY (m.Inserts+m.Updates)/(SYSDATE - t.Last_Analyzed) * s.Size_MB DESC NULLS LAST",
            :parameter=>[{:name=> t(:dragnet_helper_65_param_1_name, :default=>'Minimum number of records of table'), :size=>12, :default=>100000, :title=> t(:dragnet_helper_65_param_1_hint, :default=>'Number of records of table for consideration in selection')},
                         {:name=> t(:dragnet_helper_65_param_2_name, :default=>'Minimum days since last analysis'), :size=>12, :default=>20, :title=> t(:dragnet_helper_65_param_2_hint, :default=>'Minimum number of days since last analysis to ensure suitable values in DBA_Tab_Modifications for inserts, updates and deletes')},
            ]
        },
        {
            :name  => t(:dragnet_helper_128_name, :default=>'Tables without write access (DML) since last analysis'),
            :desc  => t(:dragnet_helper_128_desc, :default=>'Tables without any access by insert/update/delete/truncate or drop partition since last analysis.
For master data this behaviour may be default, but for transaction data this may be a hint that this table are not used no more and therefore possibly may be deleted.
For valid function of this selection table analysis should only be done if there has been DML on this table (stale-analysis).
'),
            :sql=> "SELECT Owner, Table_Name, Max_Created \"Creation time\", ROUND(SYSDATE-Max_Created) \"Age in days\",Max_Last_DDL_Time \"Last DDL Time\", Last_Analyzed \"Last analyze time\",
                                   Days_After_Analyze \"Days after last analyze\",
                                   Num_Rows, Size_MB
                    FROM   (
                            SELECT t.Owner, t.Table_Name, o.Max_Created, o.Max_Last_DDL_Time, t.Last_Analyzed,
                                   ROUND(SYSDATE - t.Last_Analyzed, 2) Days_After_Analyze,
                                   t.Num_Rows, s.Size_MB
                            FROM   DBA_Tables t
                            LEFT OUTER JOIN (SELECT Table_Owner, Table_Name, MAX(Timestamp) Timestamp
                                             FROM sys.DBA_Tab_Modifications
                                             GROUP BY Table_Owner, Table_Name
                                             HAVING SUM(Inserts) != 0 OR SUM(Updates) != 0 OR SUM(Deletes) != 0  OR MAX(Truncated) = 'YES' OR SUM(Drop_Segments) != 0
                                            ) m ON m.Table_Owner = t.Owner AND m.Table_Name = t.Table_Name
                            LEFT OUTER JOIN (SELECT Owner, Segment_Name, ROUND(SUM(Bytes)/(1024*1024),1) Size_MB
                                             FROM DBA_Segments s
                                             WHERE Owner NOT IN (#{system_schema_subselect})
                                             GROUP BY Owner, Segment_Name
                                            ) s ON s.Owner = t.Owner AND s.Segment_Name = t.Table_Name
                            LEFT OUTER JOIN (SELECT Owner, Object_Name, MAX(Created) Max_Created, MAX(Last_DDL_Time) Max_Last_DDL_Time
                                             FROM   DBA_Objects
                                             WHERE  Object_Type LIKE 'TABLE%'
                                             GROUP BY Owner, Object_Name
                                            ) o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name
                            CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                            WHERE  m.Table_Owner IS NULL AND m.Table_Name IS NULL
                            AND    t.Owner NOT IN (#{system_schema_subselect})
                            AND    (schema.name IS NULL OR schema.Name = t.Owner)
                           )
                    WHERE  Days_After_Analyze > ?
                    AND    Num_Rows >= ?
                    AND    Max_Created < SYSDATE - ?
                    ORDER BY Num_Rows*Days_After_Analyze DESC
                    ",
            :parameter=>[
                {:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_128_param_1_hint, :default=>'Check only tables for this schema (optional)')},
                {:name=> t(:dragnet_helper_128_param_2_name, :default=>'Minimum number of days after last analyze'), :size=>8, :default=>8, :title=> t(:dragnet_helper_128_param_2_hint, :default=>'Minimum number of days after last analyze to ensure that table had no DML for at least that time')},
                {:name=> t(:dragnet_helper_128_param_3_name, :default=>'Minimum number of rows'), :size=>14, :default=>0, :title=> t(:dragnet_helper_128_param_3_hint, :default=>'Check only tables with at least this number of rows. Use "0" to check also tables that have never been used (NumRows=0)')},
                {:name=> t(:dragnet_helper_128_param_4_name, :default=>'Minimum age of table (days)'), :size=>10, :default=>60, :title=> t(:dragnet_helper_128_param_4_hint, :default=>'Minimum age of table in days (time since creation) to ensure that unused table is not a current preparation for next software release')},
            ]
        },
        {
            :name  => t(:dragnet_helper_66_name, :default=>'Detection of not used columns (all values = NULL)'),
            :desc  => t(:dragnet_helper_66_desc, :default=>'Unused columns with only NULL-values Spalten can possibly be removed.
Each NULL-value of a record claims one byte if not all subsequent columns of that record are also NULL.
You can use virtual columns instead if this table structure is precondition (SAP etc.).
'),
            :sql=> "SELECT /* DB-Tools Ramm  Spalten mit komplett  NULL-Values */
                             c.Owner, c.Table_Name, c.Column_Name, t.Num_Rows, c.Num_Nulls, c.Num_Distinct
                      FROM   DBA_Tab_Columns c
                      JOIN   DBA_Tables t ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
                      WHERE  c.Num_Nulls = t.Num_Rows
                      AND    t.Num_Rows  > 0   -- Tabelle enthaelt auch Daten
                      AND    c.Owner NOT IN (#{system_schema_subselect})
                      ORDER BY t.Num_Rows DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_67_name, :default=>'Detection of less informative columns'),
            :desc  => t(:dragnet_helper_67_desc, :default=>'For columns of large tables with less DISTINCT-values meaning can be questioned.
May be it their value is redundant to other columns of that table. In this case you can extract this column as separate master-data table with n:1-relation (normalization).
'),
            :sql=> "SELECT /* DB-Tools Ramm Spalten mit wenig Distinct-Values */
                             c.Owner, c.Table_Name, c.Column_Name, t.Num_Rows, c.Num_Nulls, c.Num_Distinct, c.Avg_Col_Len,
                             ROUND((c.Avg_Col_Len*(Num_Rows-Num_Nulls)+Num_Nulls)/(1024*1024),2) Megabyte_Column
                      FROM   DBA_Tab_Columns c
                      JOIN   DBA_Tables t ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
                      WHERE  NVL(c.Num_Distinct,0) > 0
                      AND    NVL(c.Num_Distinct,0) <= ?
                      AND    (c.Num_Nulls = 0 OR UPPER(?) = 'YES')
                      AND    NVL(t.Num_Rows,0) > ?
                      AND    c.Owner NOT IN (#{system_schema_subselect})
                      ORDER BY c.Num_Distinct, t.Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_67_param_1_name, :default=>'Maximum number of distinct values of column'), :size=>8, :default=>10, :title=>t(:dragnet_helper_67_param_1_name, :default=>'Maximum number of distinct values of column for consideration in selection')},
                         {:name=>t(:dragnet_helper_67_param_2_name, :default=>'Include columns with NULL-values? (YES/NO)'), :size=>8, :default=>'YES', :title=>t(:dragnet_helper_67_param_2_name, :default=>'Also consider columns with NULL-values for this selection? (YES/NO)')},
                         {:name=>t(:dragnet_helper_param_minimal_rows_name, :default=>'Minimum number of rows in table'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_param_minimal_rows_hint, :default=>'Minimum number of rows in table for consideration in selection')}
            ]
        },
        {
            :name  => t(:dragnet_helper_68_name, :default=>'Unused marked but not physical deleted columns'),
            :desc  => t(:dragnet_helper_68_desc, :default=>'For as unused marked columns it may be worth to reorganize the table by ALTER TABLE DROP UNSED COLUMNS or recreation of table.
'),
            :sql=> 'SELECT /* DB-Tools Ramm Unused gesetzte Spalten ohne ALTER TABLE DROP UNUSED COLUMNS*/ cs.*, t.Num_Rows
                      FROM   DBA_Unused_Col_Tabs cs
                      JOIN   DBA_Tables t ON t.Owner = cs.Owner AND t.Table_Name = cs.Table_Name
                      ORDER BY t.Num_Rows*cs.Count DESC NULLS LAST',
        },
        {
            :name  => 'Dropped tables in recycle bin',
            :desc  => "Use 'PURGE RECYCLEBIN' to free space of dropped tables from recycle bin",
            :sql=> "SELECT ROUND(r.Space * t.Block_Size / (1024*1024), 3) Size_MB, r.*
                    FROM   DBA_RecycleBin r
                    LEFT OUTER JOIN DBA_Tablespaces t ON t.TableSpace_Name = r.TS_Name
                    ORDER BY Size_MB DESC NULLS LAST",
        },
        {
            :name  => t(:dragnet_helper_137_name, default: 'CHAR-columns filled with unnecessary blanks'),
            :desc  => t(:dragnet_helper_137_desc, default: "Column type CHAR is only useful if you have the majority of contents with the full character length of the column precision.
Otherwise you are storing lots of unnecessary blanks because CHAR-columns are filled with blanks until column precision.
Use data type VARCHAR2 instead in such cases.
The selection is based on two sample values per column (the lowest and the highest) and sorted by the total size of unnecessary blanks per column."),
            :sql=> "SELECT *
                    FROM   (
                            SELECT Owner, Table_Name, Column_Name, 'CHAR ('||CHAR_LENGTH||')' Data_Type, Low_Value_Char, High_Value_Char, Avg_Col_Len, (LENGTH(Low_Value_Char)+LENGTH(High_Value_Char))/2 Sample_Char_Length,
                                   Num_Rows, ROUND(Num_Rows*Char_Length / (1024*1024), 2) MB_Total,
                                   ROUND(Num_Rows*(Char_Length -  (LENGTH(Low_Value_Char)+LENGTH(High_Value_Char))/2) / (1024*1024), 2) MB_Only_For_Blanks
                            FROM   (
                                    SELECT c.*, RTRIM(UTL_I18N.RAW_TO_CHAR(Low_Value)) Low_Value_Char, RTRIM(UTL_I18N.RAW_TO_CHAR(High_Value)) High_Value_Char,
                                           t.Num_Rows
                                    FROM   DBA_Tab_Columns c
                                    JOIN   DBA_Tables t ON t.Owner = c.Owner AND t.Table_Name = c.Table_Name
                                    WHERE  c.Data_Type = 'CHAR'
                                    AND    c.Owner NOT IN (#{system_schema_subselect})
                                    AND    c.Data_Length > 1
                                   )
                            WHERE (LENGTH(Low_Value_Char)+LENGTH(High_Value_Char))/2 < CHAR_LENGTH
                           )
                    ORDER BY MB_Only_For_Blanks DESC
                    ",
        },

    ]
  end # unused_tables

end
