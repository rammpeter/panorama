# Oracle-DB: Check if an index is used in SQL Plan Management directives or optimizer hints

Datum: 2026-07-02
URL: https://rammpeter.blogspot.com/2026/07/oracle-db-check-if-index-in-used-in-sql.html
Labels: Index, Oracle Database

---

A few years ago I wrote a blog post about Identify non-relevant indexes for secure deletion.

One additional aspect that is possibly worth to consider before deleting an index is:

Are there any optimizer hints in SQL statements, SQL Patches, SQL Profiles or SQL Plan Baselines pointing to that index?

In reality, they should not be relevant because otherwise this index would not be marked as unused since longer time.

But, for clean structures it would be good to know that the index name is referenced somewhere.

You can use this SQL to scan for occurrences of the index name in SQL Profiles, Patches or SQL Plan Baselines.
In Baselines you'll usually not find the index name itself, because they mostly address the index by its column names.

SELECT DECODE(so.Obj_Type, 1, 'SQL Profile', 2, 'SQL Plan Baseline', 3, 'SQL Patch', 'Unknown') Type, so.Name, sod.Comp_Data, sod.Category
FROM sys.sqlobj$data sod
JOIN sys.sqlobj$ so ON so.Category = sod.Category AND so.Obj_Type = sod.Obj_Type AND so.Plan_ID = sod.Plan_ID
WHERE UPPER(sod.Comp_Data) LIKE '%'||'MY_INDEX_NAME'||'%'
;

In addition, you can also look for use of the index name in directly placed optimizer hints of SQL statements in the SGA:

SELECT p.SQL_ID, p.Child_Number, h.Hint_Text
FROM gv$SQL_Plan p,
 XMLTABLE(
 '/*/hint_usage/q'
 PASSING XMLTYPE(p.other_xml)
 COLUMNS hint_text CLOB PATH '.'
 ) h
WHERE p.Other_XML IS NOT NULL
AND h.Hint_Text LIKE '%'||'MY_INDEX_NAME'||'%'
;

In the analysis tool Panorama you may find these checks at the additional actions in the index list:
