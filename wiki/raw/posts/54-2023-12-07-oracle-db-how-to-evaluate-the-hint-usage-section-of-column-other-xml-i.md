# Oracle-DB: How to evaluate the "hint_usage" section of column OTHER_XML in execution plan

Datum: 2023-12-07
URL: https://rammpeter.blogspot.com/2023/12/oracle-db-how-to-evaluate-hintusage.html
Labels: Execution Plan, Oracle, Oracle Database, Oracle DB, Panorama How-To

---

What does the database really do with your optimizer hints in SQL statements?

Starting with Oracle 19c the column 'OTHER_XML' of V$SQL_Plan rsp. DBA_Hist_SQL_Plan or Plan_Table was extended by a section 'hint_usage'.

This gives information about the state of optimizer hint usage correlated with the line in the execution plan.

Example for section 'hint_usage' of OTHER_XML

Lets take this simple but useless SQL as example:
SELECT /*+ FULL(c) QB_NAME(Outer) NONSENS(c) */ * 
FROM cust.Customer c
WHERE ID_Company IN (
 SELECT /*+ USE_NL(cp) QB_NAME(Inner) */ 12 FROM sysp.Company cp WHERE RowNum < 5
 )
AND RowNum < 20;

The section 'hint_usage' in PLAN_TABLE.OTHER_XML looks like for this example:

 <hint_usage>
 <q>
 <n><![CDATA[INNER]]></n>
 <h o="EM">
 <x><![CDATA[QB_NAME(Inner)]]></x>
 </h>
 <t>
 <f><![CDATA["CP"@"INNER"]]></f>
 <h o="EM" st="NU">
 <x><![CDATA[USE_NL(cp)]]></x>
 </h>
 </t>
 </q>
 <q>
 <n><![CDATA[OUTER]]></n>
 <h o="EM">
 <x><![CDATA[QB_NAME(Outer)]]></x>
 </h>
 <h o="EM" st="PE">
 <x><![CDATA[NONSENS]]></x>
 </h>
 <t>
 <f><![CDATA["C"@"OUTER"]]></f>
 <h o="EM">
 <x><![CDATA[FULL(c)]]></x>
 </h>
 </t>
 </q>
 </hint_usage>

Structure interpretation of 'hint_usage' in OTHER_XML

Top level strucure in 'hint_usage':

 - <hint_usage> Top level block in OTHER_XML
 
 - <q> one block per query block
 
 - <n> the query block name

 - <h> the hint is directly bound to the query block, the attributes and the x-tag are directly inside this tag

 - <m> the hint scope is query block (unsure)

 - <s> the hint scope is statement

 - <t> the hint scope is join (unsure)

 - <s> one block per statement
 
 - <h> the hint is directly bound to the statement, the attributes and the x-tag are directly inside this tag

Attributes of the hint scope (m/s/t):

 - st="UR" - unresolved (‘N’ in dbms_xplan note)

Structure inside the hint scope (m/s/t):

 - <f> - the alias of the object if hint scope is object-related

 - <h> - the hint data, multiple occurences possible inside one hint scope

Attributes of the <h> tag:

 - o="EM" - Hint is supplied by the SQL definer

 - o="OU" - Hint is supplied internally by Oracle

 - o="SH" - related to MMON stats advisor auto task, SQLs are tagged with /* SQL Analyze(n,m) */

 - o="SP" - Hint is supplied by a SQL profile

 - o="SR" - Hint is supplied by a SQL profile

 - st="EU" - unused (‘U’ in dbms_xplan note)

 - st="NU" - unused (‘U’ in dbms_xplan note)

 - st="PE" - parsing syntax error (‘E’ in dbms_xplan note)

 - st="UR" - unresolved (‘N’ in dbms_xplan note)

Structure inside the <h> tag:

 - <x> the hint syntax

 - <r> optional reason for problems with that hint

Display hint usage by DBMS_XPLAN

Using the format tag '+HINT_REPORT' output from DBMS_XPLAN.DISPLAYxx will show the hint_usage info tagged with the given query block names:

Plan hash value: 3074015355
 
---------------------------------------------------------------------------------------------------------------------------------
| Id | Operation | Name | Rows | Bytes | Cost (%CPU)| Time | Pstart| Pstop |
---------------------------------------------------------------------------------------------------------------------------------
| 0 | SELECT STATEMENT | | | | 54 (100)| | | |
|* 1 | COUNT STOPKEY | | | | | | | |
|* 2 | FILTER | | | | | | | |
| 3 | PARTITION LIST ALL | | 243 | 13365 | 3 (0)| 00:00:01 | 1 | 2 |
| 4 | TABLE ACCESS STORAGE FULL FIRST ROWS| CUSTOMER | 243 | 13365 | 3 (0)| 00:00:01 | 1 | 2 |
|* 5 | FILTER | | | | | | | |
|* 6 | COUNT STOPKEY | | | | | | | |
| 7 | INDEX FULL SCAN | IX_COMPANY_ID_COUNTRY | 1 | | 1 (0)| 00:00:01 | | |
---------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
 1 - filter(ROWNUM<20)
 2 - filter( IS NOT NULL)
 5 - filter(:B1=12)
 6 - filter(ROWNUM<5)
 
Hint Report (identified by operation id / Query Block Name / Object Alias):
Total hints for statement: 5 (U - Unused (1), E - Syntax error (1))
---------------------------------------------------------------------------
 
 1 - OUTER
 E - NONSENS
 - QB_NAME(Outer)
 
 4 - OUTER / C@OUTER
 - FULL(c)
 
 5 - INNER
 - QB_NAME(Inner)
 
 7 - INNER / CP@INNER
 U - USE_NL(cp)

Display the hint usage in Panorama's execution plan view

My swiss army knife Panorama for Oracle shows the optimizer hints as part of the according execution plan line.

If the optimzer hint is erroneous or unused/ignored, then the object of the plan line gets a pink background:

To view the optimizer hints and also the query block name as its own column, toggle the display of this columns in context menu:

If not activated as own columns, the hint usage is shown in the tooltip at the object column (like here for the table CUST.CUSTOMER):

Some SQL selects for evaluation of 'hint_usage'

 Get all used combinations of tags and attributes

 SELECT t.First_Tag, First_Attribs, t.Second_tag, t.Second_Attribs, COUNT(*) 
FROM gv$SQL_Plan p,
 XMLTABLE(
 '/other_xml/hint_usage/*/*' PASSING XMLTYPE(p.other_xml)
 COLUMNS First_Tag VARCHAR2(4000) PATH '../name()',
 First_Attribs VARCHAR2(4000) PATH 'string-join(../@*, ",")',
 Second_Tag VARCHAR2(4000) PATH './name()',
 Second_Attribs VARCHAR2(4000) PATH 'string-join(@*, ",")'
 ) t
WHERE p.Other_XML IS NOT NULL
GROUP BY t.First_Tag, First_Attribs, t.Second_tag, t.Second_Attribs
ORDER BY 5 DESC
;

For a larger OLTP system this SQL brings a result like this:
 FIRST_TAG
 FIRST_ATTRIBS
 SECOND_TAG
 SECOND_ATTRIBS
 COUNT(*)

q n 34295

q t 33460

s hEM31685

s hOU20415

q hEM9804

q hOU9225

q hEM,PE5718

q m 3798

s hEM,NU3389

q hEM,NU3007

q hOU,NU604

q tUR411

qURhEM7

s hSH,NU6

qURn 3

q hSR2

q hSR,NU2

s hSR1

Get all unused, unresolved or erroneous optimizer hints

WITH hint_errors AS (SELECT /*+ NO_MERGE MATERIALIZE */ p.Inst_ID, p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Other_XML, 
 ROUND(s.Elapsed_Time/1000000, 1) Elapsed_Secs
 FROM gv$SQL_Plan p
 JOIN gv$SQL s ON s.Inst_ID = p.Inst_ID AND s.SQL_ID = p.SQL_ID AND s.Child_Number = p.Child_Number AND s.Plan_Hash_Value = p.Plan_Hash_Value 
 WHERE s.Elapsed_Time > 10000*1000000 
 AND p.Other_XML IS NOT NULL
 AND ( p.Other_XML LIKE '%st="EU"%'
 OR p.Other_XML LIKE '%st="NU"%'
 OR p.Other_XML LIKE '%st="PE"%'
 OR p.Other_XML LIKE '%st="UR"%'
 )
 ),
 hint_usages AS (SELECT p.Inst_ID, p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Elapsed_Secs, t.Hint_Usage
 FROM hint_errors p,
 XMLTABLE(
 '/other_xml/hint_usage/*' PASSING XMLTYPE(p.other_xml)
 COLUMNS Hint_Usage XMLTYPE PATH '.'
 ) t
 )
SELECT * 
FROM (
 /* Level q/t/h */ 
 SELECT h.Inst_ID, h.SQL_ID, h.Child_Number, h.Plan_Hash_Value, h.Elapsed_Secs, t.*
 FROM hint_usages h,
 XMLTABLE(
 '/*/*/h' PASSING h.Hint_Usage
 COLUMNS Attribs VARCHAR2(4000) PATH 'string-join(./@*, ",")',
 Hint VARCHAR2(4000) PATH './x',
 Reason VARCHAR2(4000) PATH './r',
 P_Name VARCHAR2(4000) PATH '../name()',
 PP_Name VARCHAR2(4000) PATH '../../name()',
 P_Attribs VARCHAR2(4000) PATH 'string-join(../@*, ",")',
 PP_Attribs VARCHAR2(4000) PATH 'string-join(../../@*, ",")'
 ) t
 UNION ALL
 /* Level q/t/h */ 
 SELECT h.Inst_ID, h.SQL_ID, h.Child_Number, h.Plan_Hash_Value, h.Elapsed_Secs, t.*
 FROM hint_usages h,
 XMLTABLE(
 '/*/h' PASSING h.Hint_Usage
 COLUMNS Attribs VARCHAR2(4000) PATH 'string-join(./@*, ",")',
 Hint VARCHAR2(4000) PATH './x',
 Reason VARCHAR2(4000) PATH './r',
 P_Name VARCHAR2(4000) PATH 'name()',
 PP_Name VARCHAR2(4000) PATH '../name()',
 P_Attribs VARCHAR2(4000) PATH 'string-join(@*, ",")',
 PP_Attribs VARCHAR2(4000) PATH 'string-join(../@*, ",")'
 ) t
 ) 
;

Thanks to Franck Pachot (¹, ²) and Rene Nyffenegger (³) for sharing their findings.
