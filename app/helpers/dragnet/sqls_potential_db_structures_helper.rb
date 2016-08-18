# encoding: utf-8
module Dragnet::SqlsPotentialDbStructuresHelper

  private

  def sqls_potential_db_structures
    [
        {
            :name  => t(:dragnet_helper_50_name, :default=> 'Possibly useful compression of tables'),
            :desc  => t(:dragnet_helper_50_desc, :default=> 'Table compression (COMPRESS FOR xxx) reduces I/O-effort by improvement of cache hit ratio.
                Decrease in size by 1/3 to 1/2 is possible.
                Min. 20% decrease of size and relevant I/O should exist to compensate CPU overhead of compression/decompression.'),
            :sql=> "SELECT /* Panorama-Tool Ramm */
                           Owner, Object_Name, Object_Type, SUM(Samples) \"Anzahl ASH-Samples\", Compression, Compress_For
                    FROM   (SELECT o.Owner, o.Object_Name, o.Object_Type, h.Samples,
                                   CASE WHEN o.Object_Type='TABLE' THEN (SELECT Compression FROM DBA_Tables t WHERE t.Owner=o.Owner AND t.Table_Name=o.Object_Name)
                                        WHEN o.Object_Type='TABLE PARTITION' THEN (SELECT Compression FROM DBA_Tab_Partitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='TABLE SUBPARTITION' THEN (SELECT Compression FROM DBA_Tab_SubPartitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.SubPartition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='INDEX' THEN (SELECT Compression FROM DBA_Indexes i WHERE i.Owner=o.Owner AND i.Index_Name=o.Object_Name)
                                        WHEN o.Object_Type='INDEX PARTITION' THEN (SELECT Compression FROM DBA_Ind_Partitions i WHERE i.Index_Owner=o.Owner AND i.Index_Name=o.Object_Name AND i.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='INDEX SUBPARTITION' THEN (SELECT Compression FROM DBA_Ind_SubPartitions i WHERE i.Index_Owner=o.Owner AND i.Index_Name=o.Object_Name AND i.SubPartition_Name = o.SubObject_Name)
                                   ELSE 'UNKNOWN'
                                   END Compression,
                                   CASE WHEN o.Object_Type='TABLE' THEN (SELECT Compress_For FROM DBA_Tables t WHERE t.Owner=o.Owner AND t.Table_Name=o.Object_Name)
                                        WHEN o.Object_Type='TABLE PARTITION' THEN (SELECT Compress_For FROM DBA_Tab_Partitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.Partition_Name = o.SubObject_Name)
                                        WHEN o.Object_Type='TABLE SUBPARTITION' THEN (SELECT Compress_For FROM DBA_Tab_SubPartitions t WHERE t.Table_Owner=o.Owner AND t.Table_Name=o.Object_Name AND t.SubPartition_Name = o.SubObject_Name)
                                   ELSE 'UNKNOWN'
                                   END Compress_For
                            FROM   (SELECT /*+ PARALLEL(h,2) */ Current_Obj#, COUNT(*) Samples
                                    FROM   DBA_Hist_Active_Sess_History h
                                    WHERE  Sample_Time > SYSDATE-?
                                    AND    Event = 'db file sequential read'
                                    GROUP BY Current_Obj#
                                    HAVING COUNT(*) > ?
                                   ) h
                            LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = h.Current_Obj#
                           ) x
                    GROUP BY Owner, Object_Name, Object_Type, Compression, Compress_For
                    ORDER BY SUM(Samples) DESC
            ",
            :parameter=>[
                {:name=> 'Number of days in history to consider', :size=>8, :default=>2, :title=> 'Number of days in history to consider in active session history'},
                {:name=> 'Min. number of samples in ASH', :size=>8, :default=>100, :title=> 'Minimum number of samples in active session history'},
            ]
        },
        {
            :name  => t(:dragnet_helper_5_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially missing indexes)'),
            :desc  => t(:dragnet_helper_5_desc, :default=> 'Protection of colums with foreign key references by index can be necessary for:
- Ensure delete performance of referenced table (suppress FullTable-Scan)
- Supress lock propagation (shared lock on index instead of table)'),
            :sql=> "SELECT /* DB-Tools Ramm  Index fehlt fuer Foreign Key*/
                           Ref.Owner, Ref.Table_Name, refcol.Column_Name, refcol.Position, reft.Num_Rows Rows_Org,
                           Ref.R_Owner, target.Table_Name Target_Table, Ref.R_Constraint_Name, targett.Num_rows Rows_Target
                    FROM   DBA_Constraints Ref
                    JOIN   DBA_Cons_Columns refcol  ON refcol.Owner = Ref.Owner AND refcol.Constraint_Name = ref.Constraint_Name
                    JOIN   DBA_Constraints target   ON target.Owner = ref.R_Owner AND target.Constraint_Name = ref.R_Constraint_Name
                    JOIN   DBA_Tables reft          ON reft.Owner = ref.Owner AND reft.Table_Name = ref.Table_Name
                    JOIN   DBA_Tables targett       ON targett.Owner = target.Owner AND targett.Table_Name = target.Table_Name
                    WHERE  Ref.Constraint_Type='R'
                    AND    NOT EXISTS (SELECT 1 FROM DBA_Ind_Columns i
                                       WHERE  i.Table_Owner     = ref.Owner
                                       AND    i.Table_Name      = ref.Table_Name
                                       AND    i.Column_Name     = refcol.Column_Name
                                       AND    i.Column_Position = refcol.Position
                                       )
                    AND Ref.Owner NOT IN ('SYS', 'SYSTEM', 'PERFSTAT', 'MDSYS', 'SYSMAN', 'OLAPSYS')
                    AND targett.Num_rows > ?
                    ORDER BY targett.Num_rows DESC NULLS LAST, refcol.Position",
            :parameter=>[{:name=>t(:dragnet_helper_5_param_1_name, :default=> 'Min. no. of rows of referenced table'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_5_param_1_hint, :default=> 'Minimum number of rows of referenced table') },]
        },
        {
            :name  => t(:dragnet_helper_107_name, :default=> 'Relevance of access on migrated / chained rows compared to total amount of table access'),
            :desc  => t(:dragnet_helper_107_desc, :default=> 'chained rows causes additional read of migrated rows in separate DB-blocks while accessing a record which is not completely contained in current block.
Chained rows can be avoided by adjusting PCTFREE and reorganization of affected table.
This selection shows the relevance of access on chained rows compared to total amount of table access.'),
            :sql=>   "WITH Inst_Filter AS (SELECT ? Instance FROM DUAL)
                      SELECT x.*, CASE WHEN \"table fetch by rowid\"+\"table scan rows gotten\" > 0 THEN
                                  ROUND(\"table fetch continued row\" / (\"table fetch by rowid\"+\"table scan rows gotten\") * 100,2)
                                  ELSE 0 END \"Pct. chained row access\"
                      FROM   (
                              SELECT /*+ NO_MERGE*/ ROUND(Begin_Interval_Time, 'MI') Start_Time,
                                     SUM(CASE WHEN Stat_Name = 'table fetch continued row' THEN Value ELSE 0 END) \"table fetch continued row\",
                                     SUM(CASE WHEN Stat_Name = 'table fetch by rowid'      THEN Value ELSE 0 END) \"table fetch by rowid\",
                                     SUM(CASE WHEN Stat_Name = 'table scan rows gotten'    THEN Value ELSE 0 END) \"table scan rows gotten\"
                              FROM   (
                                      SELECT /*+ NO_MERGE*/ ss.Begin_Interval_Time, st.Stat_Id, st.Stat_Name, ss.Min_Snap_ID, st.Snap_ID,
                                             Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY st.Snap_ID) Value
                                      FROM   (SELECT /*+ NO_MERGE*/ DBID, Instance_Number, Begin_Interval_Time, Snap_ID,
                                                     MIN(Snap_ID) OVER (PARTITION BY Instance_Number) Min_Snap_ID
                                              FROM   DBA_Hist_Snapshot ss
                                              WHERE  Begin_Interval_Time >= SYSDATE - ?
                                              AND    ( (SELECT Instance FROM Inst_Filter) IS NULL OR ss.Instance_Number = (SELECT Instance FROM Inst_Filter)    )
                                             ) ss
                                      JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                                      WHERE  st.Snap_ID = ss.Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
                                      AND    st.Stat_Name IN ('table fetch continued row', 'table fetch by rowid', 'table scan rows gotten')
                                    ) hist
                              WHERE  hist.Value >= 0    /* Ersten Snap nach Reboot ausblenden */
                              AND    hist.Snap_ID > hist.Min_Snap_ID /* Vorgaenger des ersten Snap fuer LAG wieder ausblenden */
                              GROUP BY ROUND(Begin_Interval_Time, 'MI')
                             ) x
                      ORDER BY 1
                      ",
            :parameter=>[
                {:name=>'RAC-Instance (optional)', :size=>8, :default=>'', :title=>t(:dragnet_helper_107_param_1_hint, :default=>'Optional filter for selection on RAC-instance') },
                {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }
            ]
        },
        {
            :name  => t(:dragnet_helper_69_name, :default=>'Detection of chained rows of tables'),
            :desc  => t(:dragnet_helper_69_desc, :default=>'chained rows causes additional read of migrated rows in separate DB-blocks while accessing a record which is not completely contained in current block.
Chained rows can be avoided by adjusting PCTFREE and reorganization of affected table.

This selection cannot be directly executed. Please copy PL/SQL-Code and execute external in SQL*Plus !!!'),
            :sql=> "
SET SERVEROUT ON;

DECLARE
  statval  NUMBER;
  statdiff NUMBER;
  Anzahl   NUMBER;
  StatNum  NUMBER;
  Sample_Size NUMBER := 1000;

  TYPE RowID_TableType IS TABLE OF URowID;
  RowID_Table RowID_TableType;

  FUNCTION Diff RETURN NUMBER IS
    oldval NUMBER;
  BEGIN
    oldval := statval;
    SELECT Value INTO statval
    FROM   v$SesStat
    WHERE  SID=USERENV('SID')
    AND    Statistic# = StatNum  -- consistent gets
    ;
    RETURN statval - oldval;
  END Diff;

  PROCEDURE RunTest(p_Owner IN VARCHAR2, p_Table_Name IN VARCHAR2) IS
  BEGIN
    statdiff := Diff();
    FOR i IN 1..RowID_Table.COUNT LOOP
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT /*+ NO_MERGE */ * FROM '||p_Owner||'.'||p_Table_Name||' WHERE RowID=:A1)' INTO Anzahl USING RowID_Table(i);
    END LOOP;
    statdiff := Diff();
  END RunTest;

BEGIN
  DBMS_OUTPUT.PUT_LINE('===========================================');
  DBMS_OUTPUT.PUT_LINE('Detection of chained rows: connected as user='||SYS_CONTEXT ('USERENV', 'SESSION_USER'));
  DBMS_OUTPUT.PUT_LINE('Sample-size='||Sample_Size||' rows');
  SELECT Statistic# INTO StatNum FROM v$StatName WHERE Name='consistent gets';
  FOR Rec IN (SELECT Owner, Table_Name, Num_Rows
              FROM   DBA_Tables
              WHERE  IOT_Type IS NULL
              AND    Num_Rows > 10000   -- nur genügende große Tabellen testen
              AND    Owner NOT IN ('SYS','SYSTEM')
             ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'SELECT RowID FROM '||Rec.Owner||'.'||Rec.Table_Name||' WHERE RowNum <= '||Sample_Size BULK COLLECT INTO RowID_Table;
      runTest(Rec.Owner, Rec.Table_Name);  -- der erste zum Warmlaufen und übersetzen der Cursor
      runTest(Rec.Owner, Rec.Table_Name);  -- dieser zum Zaehlen
      IF statdiff > Sample_Size THEN
        DBMS_OUTPUT.PUT_LINE('Table='||Rec.Owner||'.'||Rec.Table_Name||',   num rows='||Rec.Num_Rows||',   consistent gets='||statdiff||',   pct. chained rows='||((statdiff*100/sample_size)-100)||' %');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Table='||Rec.Owner||'.'||Rec.Table_Name||',  Error: '||SQLCODE||':'||SQLERRM);
    END;
  END LOOP;
END;
/
             ",
        },
        {
            :name  => t(:dragnet_helper_117_name, :default=>'Table access by rowid replaceable by index lookup (from current SGA)'),
            :desc  => t(:dragnet_helper_117_desc, :default=>'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.'),
            :sql=> "SELECT x.*
                    FROM   (
                            SELECT /*+ USE_HASH(t) */
                                   p.Inst_ID, p.SQL_ID, p.Plan_Hash_Value, h.SQL_Plan_Line_ID, p.Object_Owner, p.Object_Name,
                                   t.Num_Rows, t.Avg_Row_Len,
                                   h.Samples Seconds_per_SQL,
                                   SUM(Samples) OVER (PARTITION BY p.Object_Owner, p.Object_Name) Seconds_per_Object
                            FROM   (
                                    SELECT DISTINCT Inst_ID, ID, Operation, Options, SQL_ID, Plan_Hash_Value, Object_Owner, Object_Name
                                    FROM   gv$SQL_Plan
                                   ) p
                            JOIN   (
                                    SELECT Inst_ID, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, SQL_ID,
                                           SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Samples
                                    FROM   gv$Active_Session_History
                                    WHERE  SQL_Plan_Line_ID IS NOT NULL
                                    GROUP BY Inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                   ) h ON h.Inst_ID=p.Inst_ID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                            LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                            WHERE  p.Operation = 'TABLE ACCESS' AND p.Options = 'BY INDEX ROWID'
                            AND    p.Object_Owner NOT IN ('SYS', 'SYSTEM')
                            AND    NVL(t.Num_Rows, 0) < ?
                           ) x
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC",
            :parameter=>[{:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>10, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        {
            :name  => t(:dragnet_helper_118_name, :default=>'Table access by rowid replaceable by index lookup (from AWR history)'),
            :desc  => t(:dragnet_helper_118_desc, :default=>'For smaller tables with less columns and excessive access it can be worth to substitute index range scan + table access by rowid with single index range scan via special index with all accessed columns.
Usable with Oracle 11g and above only.'),
            :sql=> "SELECT *
                    FROM   (
                            SELECT /*+ USE_HASH(t) */
                                   h.Instance_Number, p.SQL_ID, p.Plan_Hash_Value, h.SQL_Plan_Line_ID, p.Object_Owner, p.Object_Name, t.Num_Rows, t.Avg_Row_Len,
                                   h.Samples*10 Seconds_per_SQL,
                                   SUM(Samples*10) OVER (PARTITION BY p.Object_Owner, p.Object_Name) Seconds_per_Object
                            FROM   DBA_Hist_SQL_Plan p
                            JOIN   (
                                    SELECT /*+ PARALLEL(h,2) */
                                           DBID, Instance_Number, MIN(Sample_Time) Min_Sample_Time, MAX(Sample_Time) Max_Sample_Time, SQL_ID,
                                           SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Samples
                                    FROM   DBA_Hist_Active_Sess_History h
                                    WHERE  SQL_Plan_Line_ID IS NOT NULL
                                    AND    Sample_Time > SYSDATE - ?
                                    GROUP BY DBID, Instance_Number, SQL_ID, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
                                   ) h ON h.DBID = p.DBID AND h.SQL_ID=p.SQL_ID AND h.SQL_Plan_Hash_Value=p.Plan_Hash_Value AND h.SQL_Plan_Line_ID=p.ID
                            LEFT OUTER JOIN DBA_Tables t ON t.Owner = p.Object_Owner AND t.Table_Name = p.Object_Name
                            WHERE  p.Operation = 'TABLE ACCESS' AND p.Options = 'BY INDEX ROWID'
                            AND    p.Object_Owner NOT IN ('SYS', 'SYSTEM')
                            AND    NVL(t.Num_Rows, 0) < ?
                           )
                    WHERE  Seconds_Per_Object  > ?
                    ORDER BY Seconds_Per_Object DESC, Seconds_Per_SQL DESC
                    ",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
                         {:name=> 'Maximum number of rows in table', :size=>14, :default=>100000, :title=> 'Maximum number of rows in table. For smaller table it is mostly no matter to have additional indexes.'},
                         {:name=> 'Minimum number of seconds in wait', :size=>8, :default=>100, :title=> 'Mimimum number of seconds in wait for table access by rowid on this table to be worth to consider.'}]
        },
        {
            :name  => t(:dragnet_helper_127_name, :default=>'Possibly expensive TABLE ACCESS BY INDEX ROWID with additional filter predicates on table'),
            :desc  => t(:dragnet_helper_127_desc, :default=>'If in a SQL a table has additional filter conditions that are not covered by the used index you may consider to extend the index by these filter conditions.
This would ensure that you do the more expensive TABLE ACCESS BY ROWID only if that table row matches all your access conditions checked by the index.
This selection considers current SGA'),
            :sql=> "
              SELECT Table_Owner, Table_Name, Index_Name,
                     Elapsed_Secs               \"Elapsed time SQL total (sec.)\",
                     Ash_Seconds_Tab            \"Table access time ASH (sec.)\",
                     SQL_ID_Max_Elapsed_Secs    \"SQL-ID with max. total elapsed\",
                     SQL_ID_Max_Ash_Seconds_Tab \"SQL-ID with max. ASH per table\",
                     Index_Access               \"Access criteria on index\",
                     Table_Filter               \"Filter criteria on table\"
              FROM   (
                      SELECT Table_Owner, Table_Name, Index_Name,
                             SUM(Elapsed_Secs) Elapsed_Secs, SUM(Ash_Seconds_Tab) Ash_Seconds_Tab,
                             MAX(SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Elapsed_Secs) SQL_ID_Max_Elapsed_Secs,
                             MAX(SQL_ID) KEEP (DENSE_RANK LAST ORDER BY Ash_Seconds_Tab) SQL_ID_Max_Ash_Seconds_Tab,
                             Index_Access, Table_Filter
                      FROM   (
                              SELECT ind.Inst_ID, ind.SQL_ID, ind.Plan_Hash_Value, ind.Child_Number, ind.ID Ind_ID, tab.ID tab_ID, tab.Table_Owner, tab.Table_Name, ind.Index_Name,
                                     ROUND(s.Elapsed_Time/1000000) Elapsed_Secs, ash.ash_Seconds_Tab,
                                     ind.Access_Predicates Index_Access, tab.Filter_Predicates Table_Filter
                              FROM   (
                                      SELECT /*+ NO_MERGE */  Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, ID, Object_Owner Index_Owner, Object_Name Index_Name, Access_Predicates
                                      FROM   gv$SQL_Plan
                                      WHERE  Access_Predicates IS NOT NULL
                                      AND    Operation LIKE 'INDEX%'
                                      AND    Object_Owner NOT IN ('SYS')
                                     ) ind
                              JOIN   DBA_Indexes i ON i.Owner = ind.Index_Owner AND i.Index_Name = ind.Index_Name
                              JOIN   (
                                      SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, ID, Object_Owner Table_Owner, Object_Name Table_Name, Filter_Predicates
                                      FROM   gv$SQL_Plan
                                      WHERE  Filter_Predicates IS NOT NULL
                                      AND    Operation LIKE 'TABLE ACCESS%'
                                      AND    Options LIKE 'BY INDEX ROWID%'
                                      AND    Object_Owner NOT IN ('SYS')
                                     ) tab ON tab.Inst_ID = ind.Inst_ID AND tab.SQL_ID = ind.SQL_ID AND tab.Plan_Hash_Value = ind.Plan_Hash_Value AND tab.Child_Number = ind.Child_Number AND
                                              tab.Table_Owner = i.Table_Owner AND tab.Table_Name = i.Table_Name AND tab.ID < ind.ID -- Index kommt unter table beim index-Zugriff
                              JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, Plan_Hash_Value, Child_Number, Elapsed_Time
                                      FROM   gv$SQL
                                      WHERE  Elapsed_Time > ? * 1000000
                                     )s ON S.INST_ID = ind.Inst_ID AND s.SQL_ID = ind.SQL_ID AND s.Plan_Hash_Value = ind.Plan_Hash_Value AND s.Child_Number = ind.Child_Number
                              LEFT OUTER JOIN ( -- Ash may be removed after short time but SQL remains in SGA
                                      SELECT /*+ NO_MERGE */ inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Child_Number, SQL_Plan_Line_ID, COUNT(*) Ash_Seconds_Tab
                                      FROM   gv$Active_Session_History
                                      WHERE  SQL_Plan_Hash_Value != 0 -- kein SQL
                                      GROUP BY inst_ID, SQL_ID, SQL_Plan_Hash_Value, SQL_Child_Number, SQL_Plan_Line_ID
                                     ) ash ON ash.INST_ID = ind.Inst_ID AND ash.SQL_ID = ind.SQL_ID AND ash.SQL_Plan_Hash_Value = ind.Plan_Hash_Value AND ash.SQL_Child_Number = ind.Child_Number AND ash.SQL_Plan_Line_ID = tab.ID
                             )
                      GROUP BY Table_Owner, Table_Name, Index_Name, Index_Access, Table_Filter
                     )
              WHERE  Elapsed_Secs >= ?
              AND    NVL(Ash_Seconds_Tab, ?) >= 0
              ORDER BY Elapsed_Secs + NVL(Ash_Seconds_Tab, 0) DESC
            ",
            :parameter=>[{:name=>t(:dragnet_helper_127_param_1_name, :default=>'Minimum elapsed seconds of SQL in SGA to be considered in selection'), :size=>8, :default=>10, :title=>t(:dragnet_helper_127_param_1_hint, :default=>'Minimum amount of elapsed seconds an SQL must have in GV$SQL to be considered in this selection') },
                         {:name=>t(:dragnet_helper_127_param_2_name, :default=>'Minimum elapsed seconds as sum over all SQLs in SGA per accessed table'), :size=>8, :default=>100, :title=>t(:dragnet_helper_127_param_2_hint, :default=>'Minimum amount of elapsed seconds of all SQLs in SGA that are accessing the considered table to be shown in this selection') },
                         {:name=>t(:dragnet_helper_127_param_3_name, :default=>'Minimum elapsed seconds in active session history for TABLE ACCESS BY ROWID'), :size=>8, :default=>0, :title=>t(:dragnet_helper_127_param_3_hint, :default=>"Minimum amount of elapsed seconds in GV$Active_Session_History of for TABLE ACCESS BY ROWID on the considered table to be shown in this selection. Value=0 means: show this table access also if there are no records in active session history for this access.") },
            ]
        },
    ]
  end # sqls_potential_db_structures


end
