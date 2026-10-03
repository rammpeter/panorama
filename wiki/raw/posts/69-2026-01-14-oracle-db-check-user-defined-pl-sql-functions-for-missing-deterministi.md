# Oracle-DB: Check user-defined PL/SQL functions for missing DETERMINISTIC flag

Datum: 2026-01-14
URL: https://rammpeter.blogspot.com/2026/01/oracle-db-check-user-defined-plsql.html
Labels: Deterministic, Oracle Database, Performance tuning

---

If using user-defined PL/SQL functions in SQL, it is crucial for the optimizer to know if a function is deterministic or not.
Deterministic means, that the result of a function call is stable for subsequent calls with the same call paramater values.
You need to tell the optimizer that the result can be considered as stable by adding the keyword DETERMINISTIC to the function declaration.
CREATE OR REPLACE FUNCTION MyFunc() RETURN NUMBER DETERMINISTIC ... 

If knowing that a function is deterministic, the SQL engine can cache the function results for repeated calls of this function.
This can make a huge difference for the SQL execution effort.

Consider an example:

A table MyTab has 1 mio. records.
A package function does some calculations returning a value that is used as filter criteria at access on MyTab.

CREATE TABLE MyTab(ID NUMBER);

INSERT INTO MyTab SELECT Level FROM DUAL CONNECT BY LEVEL <= 1000000;
COMMIT;

CREATE OR REPLACE PACKAGE MyPack AS
 FUNCTION MyFunc RETURN NUMBER;
 PROCEDURE Reset;
END MyPack;
/

CREATE OR REPLACE PACKAGE BODY MyPack AS
 Counter NUMBER := 0;

 FUNCTION MyFunc RETURN NUMBER IS
 BEGIN
 Counter := Counter + 1;
 RETURN 5;
 END MyFunc;
 
 PROCEDURE Reset IS
 BEGIN
 DBMS_OUTPUT.PUT_LINE('Counter = '||Counter);
 Counter := 0;
 END Reset;
END MyPack; 
/

Now let's check what happens. 

SET SERVEROUTPUT ON;
SELECT * FROM MyTab WHERE ID = MyPack.MyFunc;
EXEC MyPack.Reset;

5

Counter = 1000000

The table MyTab was read by full table scan, only one of the 1 million rows equals the function return value 5.

The function call is not related to any row value of the table, nethertheless the fuction has been called 1 mio times, because the DB could not know if it will return the same value for each call.

Now add the keyword DETERMINISTIC to the function declaration and try again:

CREATE OR REPLACE PACKAGE MyPack AS
 FUNCTION MyFunc RETURN NUMBER DETERMINISTIC;
 PROCEDURE Reset;
END MyPack; 
/

Counter = 1

The function needs to be called only once.

So there might be a huge difference in execution time for your SQLs if you have such pittfalls in your function declarations where really deterministic functions are not declared as such.

But how to recognize which functions in your DB could be worth to declare as DETERMINISTIC?

My appproach scans a DB for long running SQLs that uses non-deterministic user-defined PL/SQL functions.

It's up to you to evaluate and decide if this functions could be tagged as DETERMINISTIC or not.
But this selection gives an initial insight into where pitfalls such as those in the above example may be hidden.

Especially the shown function use in access or filter predicates of the execution plan gives a hint where frequent unnecessary function executions may occur.

The reuse of function results is limited to a single SQL execution. 
It might therefore also make sense to label functions as DETERMINISTIC that are not actually deterministic. 

For example, if a PL/SQL function selects values from master data tables, then the function is not determinisitic because the content of this tables may change.
But in reality, you are not interested in detecting such a change during a singe SQL execution. So you can tag this function DETERMINISTIC nethertheless and ensure that is is called much less frequently than otherwise.

This PL/SQL block scans for 
use of non-deterministic functions in SQL statements, the DBMS_OUTPUT result is a JSON-formatted line per match:

SET SERVEROUTPUT ON;
DECLARE
 TYPE proc_RT IS RECORD(
 Owner VARCHAR2(128),
 Package_Name VARCHAR2(128),
 Function_Name VARCHAR2(128)
 );
 proc_rec proc_RT;
 TYPE Proc_TT IS TABLE OF Proc_RT INDEX BY VARCHAR2(2000);
 proc_table Proc_TT;

 TYPE Char_Table_Type IS TABLE OF CHAR(1);
 Char_Table Char_Table_Type := Char_Table_Type(' ', '(', '!', '=', '<', '>', '+', '-', '*', '/'); -- delimiters chars to use for tokenization of SQL
 char_table_count INTEGER := Char_Table.COUNT;

 Start_Pos INTEGER;
 End_pos INTEGER;
 Test_Pos INTEGER;
 l_text CLOB;
 l_match VARCHAR2(4000);
 full_match VARCHAR2(4000);
 l_json VARCHAR2(4000);
 Plan_Line_ID_Access INTEGER;
 Plan_Line_ID_Filter INTEGER;
 Access_Text VARCHAR2(4000);
 Filter_Text VARCHAR2(4000);
 Search_Text VARCHAR2(4000); -- The text searched in access or filter criteria

 FUNCTION JSON_Esc(p_In VARCHAR2) RETURN VARCHAR2 IS
 BEGIN
 RETURN REPLACE(p_In, '"', '\"');
 END JSON_Esc;

BEGIN
 FOR p_Rec IN (SELECT Owner, Package_Name, Function_Name, Compare_Name
 FROM (
 SELECT Owner, NULL Package_Name, Object_Name Function_Name, Deterministic, Object_Name Compare_Name
 FROM DBA_Procedures
 WHERE Object_Type = 'FUNCTION'
 UNION ALL
 SELECT p.Owner, p.Object_Name Package_Name, p.Procedure_Name Function_Name, p.Deterministic, p.Object_Name||'.'||p.Procedure_Name Compare_Name
 FROM DBA_Procedures p
 JOIN DBA_Arguments a ON a.Owner = p.Owner AND a.Package_Name = p.Object_Name AND a.Object_Name = p.Procedure_Name
 WHERE p.Object_Type = 'PACKAGE'
 AND a.Argument_Name IS NULL /* Program is a function with a return value */
 )
 WHERE Owner NOT IN (SELECT UserName FROM All_Users WHERE Oracle_Maintained = 'Y')
 AND Deterministic = 'NO'
 ) LOOP
 -- Lookup with function name only
 proc_table(p_Rec.Compare_Name) := Proc_RT(p_Rec.Owner, p_Rec.Package_Name, p_Rec.Function_Name);
 -- Lookup with function name qualified with owner
 proc_table(p_Rec.Owner||'.'||p_Rec.Compare_Name) := Proc_RT(p_Rec.Owner, p_Rec.Package_Name, p_Rec.Function_Name);
 END LOOP;

 FOR t_Rec IN (SELECT Instance_Number, SQL_ID, Parsing_Schema_Name, SQL_Text, Elapsed_Secs
 FROM (
 SELECT Instance_Number, SQL_ID, Parsing_Schema_Name,
 LTRIM(SQL_Text, CHR(10) || CHR(13) || ' ' || CHR(9)) SQL_Text, /* remove leading whitespaces from SQL */
 SUM(Elapsed_Secs) OVER (PARTITION BY Instance_Number, SQL_ID, Parsing_Schema_Name) Elapsed_Secs,
 ROW_NUMBER() OVER (PARTITION BY Instance_Number, SQL_ID, Parsing_Schema_Name ORDER BY 1) AS rn /* Because of no aggregate functions on CLOB */
 FROM (
 SELECT Inst_ID Instance_Number, SQL_ID, UPPER(SQL_FullText) SQL_Text, Parsing_Schema_Name, Elapsed_Time/1000000 Elapsed_Secs
 FROM gv$SQLArea
 WHERE Command_Type != 47 /* No PL/SQL */
 UNION ALL
 SELECT h.Instance_Number, h.SQL_ID, UPPER(t.SQL_Text) SQL_Text, h.Parsing_Schema_Name, h.Elapsed_Secs
 FROM (SELECT st.Instance_Number, st.SQL_ID, st.Parsing_Schema_Name, SUM(st.Elapsed_Time_Delta)/1000000 Elapsed_Secs
 FROM DBA_Hist_SQLStat st
 JOIN DBA_Hist_Snapshot ss ON ss.DBID = st.DBID AND ss.Snap_ID = st.Snap_ID AND ss.Instance_Number = st.Instance_Number
 WHERE ss.Begin_Interval_Time > SYSDATE - 2 /* The number of days back in time to consider */
 GROUP BY st.Instance_Number, st.SQL_ID, st.Parsing_Schema_Name
 ) h
 JOIN DBA_Hist_SQLText t ON t.SQL_ID = h.SQL_ID
 )
 WHERE Elapsed_Secs > 1000 /* The minimum runtime to be considered in query */
 )
 WHERE RN = 1 /* Select one occurrence of SQL text per SQL-ID only */
 AND SQL_Text NOT LIKE 'BEGIN%' /* No command_type in DBA_Hist_SQLStat to filter PL/SQL */
 AND SQL_Text NOT LIKE 'DECLARE%'
 ) LOOP
 Start_Pos := 1;
 l_text := t_Rec.SQL_Text;
 LOOP
 -- Look for the next delimiter
 End_pos := 0; -- start value
 FOR i IN 1..char_table_count LOOP
 Test_Pos := INSTR(l_text, Char_Table(i), Start_Pos);
 IF Test_Pos > 0 AND ( End_Pos = 0 OR Test_Pos < End_Pos) THEN
 End_Pos := Test_Pos;
 END IF;
 END LOOP;

 BEGIN
 IF End_Pos > 0 THEN
 l_match := SUBSTR(l_text, Start_Pos, End_pos-Start_Pos);
 ELSE
 l_match := SUBSTR(l_text, Start_Pos); -- The rest of the string
 END IF;

 IF proc_Table.EXISTS(l_match) -- Either owner and function name or only function name match
 THEN
 proc_rec := proc_Table(l_match); -- For reuse of values
 -- Get the following parameter for matching function call
 -- Check if parameters follow immediately (after end_pos are only spaces up to an opening parenthesis)
 full_match := l_match; -- Default if no parameter list follows
 IF End_Pos > 0 AND REGEXP_LIKE(SUBSTR(l_text, End_Pos), '^\s*\(') THEN -- opening parenthesis directly after or after spaces
 End_Pos := INSTR(l_text, ')', Start_Pos);
 IF End_Pos > 0 THEN
 full_match := SUBSTR(l_text, Start_Pos, End_pos-Start_Pos + 1);
 ELSE
 full_match := SUBSTR(l_text, Start_Pos); -- The rest of the string
 END IF;
 END IF;

 -- Get the plan line id and content if used in access or filter predicates
 -- Take into account that the owner of the object is not stored in access or filter criterias if same as executor
 Search_Text := '%'||CASE WHEN proc_rec.Package_Name IS NULL THEN '' ELSE proc_rec.Package_Name||'.' END||proc_rec.Function_Name||'%';

 SELECT MIN(ID), MIN(Access_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Access, Access_Text
 FROM gv$SQL_PLan
 WHERE SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Access_Predicates), '"', '') LIKE Search_Text
 ;
 IF Plan_Line_ID_Access IS NULL THEN
 SELECT MIN(ID), MIN(Access_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Access, Access_Text
 FROM DBA_Hist_SQL_PLan
 WHERE SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Access_Predicates), '"', '') LIKE Search_Text
 ;
 END IF;

 SELECT MIN(ID), MIN(Filter_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Filter, Filter_Text
 FROM gv$SQL_PLan
 WHERE SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Filter_Predicates), '"', '') LIKE Search_Text
 ;
 IF Plan_Line_ID_Filter IS NULL THEN
 SELECT MIN(ID), MIN(Filter_Predicates) KEEP (DENSE_RANK FIRST ORDER BY ID) INTO Plan_Line_ID_Filter, Filter_Text
 FROM DBA_Hist_SQL_PLan
 WHERE SQL_ID = t_Rec.SQL_ID AND REPLACE(UPPER(Filter_Predicates), '"', '') LIKE Search_Text
 ;
 END IF;

 l_json := '{' ||
 '"Instance": ' || t_Rec.Instance_Number || ', ' ||
 '"SQL-ID": "' || JSON_Esc(t_Rec.SQL_ID) || '", ' ||
 '"Parsing Schema Name": "' || t_Rec.Parsing_Schema_Name || '", ' ||
 '"Elapsed Secs": ' || ROUND(t_Rec.Elapsed_Secs) || ', ' ||
 '"Owner": "' || proc_rec.Owner || '", ' ||
 '"Package Name": "' || proc_rec.Package_Name || '", ' ||
 '"Function Name": "' || proc_rec.Function_Name || '", ' ||
 '"Match in SQL": "' || JSON_Esc(full_match) || '", ' ||
 '"Plan Line ID Access": ' || CASE WHEN Plan_Line_ID_Access IS NULL THEN 'null' ELSE TO_CHAR(Plan_Line_ID_Access) END || ', ' ||
 '"Access Predicates": "' || JSON_Esc(Access_Text) || '", ' ||
 '"Plan Line ID Filter": ' || CASE WHEN Plan_Line_ID_Filter IS NULL THEN 'null' ELSE TO_CHAR(Plan_Line_ID_Filter) END || ', ' ||
 '"Filter Predicates": "' || JSON_Esc(Filter_Text) || '" ' ||
 '}';
 DBMS_OUTPUT.PUT_LINE(l_json);
 END IF;
 EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE != -6502 THEN -- End_Pos > 4000 raises ORA-06502: PL/SQL: numeric or value error: character string buffer too small
 RAISE;
 END IF;
 END;
 EXIT WHEN End_Pos = 0;
 Start_Pos := End_Pos + 1;
 END LOOP;
 END LOOP;
END;
/

It is much more convenient to perform this check using my free analysis tool Panorama, where this check can be found alongside many others in the “Dragnet investigation” section.
