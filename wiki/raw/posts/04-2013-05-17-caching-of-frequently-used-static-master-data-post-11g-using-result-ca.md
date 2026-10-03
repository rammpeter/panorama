# Caching of frequently used static master data (post 11g, using RESULT_CACHE)

Datum: 2013-05-17
URL: https://rammpeter.blogspot.com/2017/03/caching-of-frequently-used-static_25.html
Labels: Code templates

---

- frequent access on small tables includes risk of hot blocks in db-cache, especially if tables are mass-joined by nested loop operations

- Joining this master tables by hash joins reduces number of block access in db cache, but requires large data transfer for hash operations and possibly access to TEMP tablespace

- Often these master data may be cached in local DB session, for session pooling environment or long living sessions in addition with content aging for guaranteed currentness of data

- This example shows a PL/SQL package for caching of table data with 11g-feature “function result caching”

- For usage runtime measuring should be done to decide between these caching or usage of hash joins

p.s.: More effective than this solution may be caching master data within application layer without access to PL/SQL

CREATE OR REPLACE PACKAGE Cache_TableAlias AS

--------------------------------------------------------------------------------
-- Author : %$LastChangedBy: arosenfe $derived_by: ramm %
-- Version : %$LastChangedRevision: 50498 $version: 3 %
-- Last Change : %$LastChangedDate: 2013-01-09 11:38:00 +0100 (Wed, 09 Jan 2013) $date_created: 2010/02/23 08:16:55 %
--
-- Description: Cachen von Daten der Tabelle innerhalb SQL-Session
-- Dient zum Abfangen von Mehrfach-Zugriffen / Hot-Blocks im NestedLoop

-- Fehltreffer in der Tabelle (incl. NULL als Parameter) werden mit Exception beantwortet
-- Evtl. NULL-Handling der ID muss vor dem Aufruf der Funktionen gehandelt werden

-- Aktuell ist kein Schwellwert fuer Cache-Groesse implentiert.
-- Durch die Nutzer ist sicherzustellen, dass Nutzung des Cachings
-- nur im Rahmen des verfuegbaren Memory stattfindet (ca. < 10000 Records) !!!
-- Auf Implementierung Cache-Obergrenze wurde in Anbetracht der Mengen bewusst verzichtet,

-- Testen lässt sich die Funktion des Caches easy per Test des folgenden Stmt. auf leeres Result:
-- SELECT /*+ PARALLEL(m) */ * FROM SchemaAlias.TableAlias m
-- WHERE ColumnAlias != SchemaAlias.Cache_TableAlias.getColumnAliasByID(ID);

-- Fuer Anwendung bitte SchemaAlias, TableAlias und ColumnAlias mit konkreten Werten ersetzen
--------------------------------------------------------------------------------

 -- Zugriff auf einzelnes Feld des Records für Anwendung in SQL-Statements
 FUNCTION getColumnAliasByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return SchemaAlias.TableAlias.ColumnAlias%TYPE PARALLEL_ENABLE RESULT_CACHE;

END Cache_TableAlias;
/
SHOW ERRORS;
CREATE OR REPLACE PACKAGE BODY Cache_TableAlias AS
 FUNCTION getByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return SchemaAlias.TableAlias%ROWTYPE PARALLEL_ENABLE IS
 v_Result SchemaAlias.TableAlias%ROWTYPE;
 BEGIN
 SELECT /*+ "Package SchemaAlias.Cache_TableAlias" */ * INTO v_Result
 FROM SchemaAlias.TableAlias
 WHERE ID=p_ID
 ;
 RETURN v_Result;
 EXCEPTION
 WHEN NO_DATA_FOUND THEN
 IF p_ID IS NULL THEN
 RAISE_APPLICATION_ERROR(-20099, 'Access to SchemaAlias.TableAlias with ID=NULL not supported', TRUE);
 ELSE
 RAISE_APPLICATION_ERROR(-20099, 'Record with ID='||p_ID||' does not exist in table SchemaAlias.TableAlias', TRUE);
 END IF;
 END getByID;

 -- Zugriff auf einzelnes Feld des Records für Anwendung in SQL-Statements
 FUNCTION getColumnAliasByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return SchemaAlias.TableAlias.ColumnAlias%TYPE PARALLEL_ENABLE RESULT_CACHE IS
 BEGIN
 RETURN getByID(p_ID).ColumnAlias;
 END getColumnAliasByID;
END Cache_TableAlias;
/
SHOW ERRORS;
