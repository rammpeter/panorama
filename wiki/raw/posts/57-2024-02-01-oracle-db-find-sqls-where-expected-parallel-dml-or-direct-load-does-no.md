# Oracle-DB: Find SQLs where expected parallel DML or direct load does not work

Datum: 2024-02-01
URL: https://rammpeter.blogspot.com/2024/02/oracle-db-find-sqls-where-expected.html
Labels: 

---

If you try to use parallel DML or direct load in SQL statements by placing the appropiate optimizer hints (PARALLEL, APPEND etc.),
there might be several reasons why the DB ignores them.

For example, if you want to execute DML in parallel you need to enable the session to do this before by executing ALTER SESSION ENABLE PARALLEL DML;
.
There are lots of similar pitfalls that may prevent the DB from using the expected execution path.

The free performance analysis tool Panorama offers a way to scan your entire database for SQLs where parallel DML or direct load should have been used but in reality is not.

Use the shown selection from menu "Dragnet investigation" (point 2.2.12) to execute this check and find SQLs that are not executed as expected. The result is sorted by the time this SQLs took to execute. The link in column "sql id" allows you to dig deeper in the details of the found SQL statement.

Precondition is licensing of Oracle Diagnostics Pack or the use of Panorama-Sampler as an alternative.

Without using "Panorama" you can also execute the following SQL manually. You should have licensed the Oracle Diagnostics Pack and replace the DBID with the numeric value of your DB ID. 

WITH Plans AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, Plan_Hash_Value, PDML_Reason, IDL_Reason
 FROM (SELECT SQL_ID, Plan_Hash_Value,
 EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = "pdml_reason"]') PDML_Reason,
 EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = "idl_reason"]') IDL_Reason
 FROM gv$SQL_Plan
 WHERE Other_XML LIKE '%pdml_reason%' OR Other_XML LIKE '%idl_reason%'
 UNION ALL
 SELECT SQL_ID, Plan_Hash_Value,
 EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = "pdml_reason"]') pdml_reason,
 EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = "idl_reason"]') IDL_Reason
 FROM DBA_Hist_SQL_Plan
 WHERE DBID = :DBID /* do not count multiple times for multiple different DBIDs/ConIDs */
 AND Other_XML LIKE '%pdml_reason%' OR Other_XML LIKE '%idl_reason%'
 )
 WHERE PDML_Reason IS NOT NULL OR IDL_Reason IS NOT NULL
 GROUP BY SQL_ID, Plan_Hash_Value, PDML_Reason, IDL_Reason /* DISTINCT */
 ),
 Min_Ash AS (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID),
 ASH AS (SELECT /*+ NO_MERGE MATERIALIZE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, SUM(Elapsed_Secs) Elapsed_Secs
 FROM (SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, COUNT(*) Elapsed_Secs
 FROM gv$Active_Session_History
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
 UNION ALL
 SELECT /*+ NO_MERGE */ SQL_ID, SQL_Plan_Hash_Value, User_ID, COUNT(*) * 10 Elapsed_Secs
 FROM DBA_Hist_Active_Sess_History h
 JOIN Min_Ash ma ON ma.Inst_ID = h.Instance_Number
 WHERE Sample_Time > SYSDATE - :Considered_Days_Back
 AND Sample_Time < ma.Min_Sample_Time
 AND DBID = :DBID /* do not count multiple times for multiple different DBIDs/ConIDs */
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
 )
 WHERE User_ID NOT IN (SELECT /*+ NO_MERGE */ User_ID FROM All_Users WHERE Oracle_Maintained = 'Y')
 GROUP BY SQL_ID, SQL_Plan_Hash_Value, User_ID
 )
SELECT /*+ LEADING(p) USE_HASH(ash) */
 p.SQL_ID, p.Plan_Hash_Value, p.PDML_Reason, p.IDL_Reason, u.UserName, SUM(ash.Elapsed_Secs) Elapsed_Secs
FROM Plans p
JOIN Ash ON ash.SQL_ID = p.SQL_ID AND ash.SQL_Plan_Hash_Value = p.Plan_Hash_Value
LEFT OUTER JOIN All_Users u ON u.User_ID = ash.User_ID
GROUP BY p.SQL_ID, p.Plan_Hash_Value, p.PDML_Reason, p.IDL_Reason, u.UserName
ORDER BY SUM(ash.Elapsed_Secs) DESC
