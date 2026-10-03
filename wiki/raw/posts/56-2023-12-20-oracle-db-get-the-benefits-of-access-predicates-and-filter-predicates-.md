# Oracle-DB: Get the benefits of Access_Predicates and Filter_Predicates in AWR starting with 19.19 

Datum: 2023-12-20
URL: https://rammpeter.blogspot.com/2023/12/oracle-db-get-benefits-of.html
Labels: Oracle Database

---

The release 19.19 of the Oracle DB got the long awaited populating of Access_Predicates and Filter_Predicates in DBA_Hist_SQL_Plan (as backport from 21c).
So far so good, after decades of complaints.

But as the execution plans already stored in the AWR before 19.19 are without a time reference, Access_Predicates and Filter_Predicates for SQLs are not filled,
as long as the plans from before 19.19 still exist.

These plans are independent of the AWR retention time and therefore remain in the old state without Access_Predicates and Filter_Predicates forever as long as the SQLs are still contained in upcoming AWR snapshots.

A solution for that behaviour is, to manually remove the old plans to trigger storage of current plans from SGA again.

If executed once as SYSDBA, this script deletes all the execution plans saved in the AWR for which the Access_Predicates and Filter_Predicates columns are not filled.

These plans will be saved again from SGA with the next AWR snapshots, but then including the Access_Predicates and Filter_Predicates.

Runtime of the script is approx. 10..60 minutes in transactions of 2 seconds each.

-- Remove pre 19.19 plans without access_predicates and filter_predicates from AWR
-- Peter Ramm, 2023-12-20
DECLARE
 v_Amount NUMBER;
BEGIN
 LOOP
 DELETE FROM sys.WRH$_SQL_PLan
 WHERE (DBID, SQL_ID, Plan_Hash_Value) IN (
 SELECT DBID, SQL_ID, Plan_Hash_Value
 FROM (
 SELECT DBID, SQL_ID, Plan_Hash_Value, MAX(Access_Predicates) Max_Access, MAX(Filter_Predicates) Max_Filter 
 FROM sys.WRH$_SQL_PLan 
 GROUP BY DBID, SQL_ID, Plan_Hash_Value 
 )
 WHERE Max_Access IS NULL AND Max_Filter IS NULL 
 AND RowNum < 100
 ) 
 ;
 COMMIT;
 SELECT COUNT(*) INTO v_Amount
 FROM (
 SELECT DBID, SQL_ID, Plan_Hash_Value, MAX(Access_Predicates) Max_Access, MAX(Filter_Predicates) Max_Filter 
 FROM sys.WRH$_SQL_PLan 
 GROUP BY DBID, SQL_ID, Plan_Hash_Value 
 )
 WHERE Max_Access IS NULL AND Max_Filter IS NULL 
 ;
 EXIT WHEN v_Amount = 0; 
 END LOOP;
END;
/
