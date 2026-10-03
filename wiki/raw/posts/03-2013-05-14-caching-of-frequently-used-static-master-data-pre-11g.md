# Caching of frequently used static master data (pre 11g)

Datum: 2013-05-14
URL: https://rammpeter.blogspot.com/2017/03/caching-of-frequently-used-static.html
Labels: Code templates

---

- frequent access on small tables includes risk of hot blocks in db-cache, especially if tables are mass-joined by nested loop operations

- Joining this master tables by hash joins reduces number of block access in db cache, but requires large data transfer for hash operations and possibly access to TEMP tablespace

- Often these master data may be cached in local DB session, for session pooling environment or long living sessions in addition with content aging for guaranteed currentness of data

- This example shows a PL/SQL package for caching of table data without 11g-feature “function result caching”

- For usage runtime measuring should be done to decide between these caching or usage of hash joins

- From 11g function result caching may be used instead of this solution

p.s.: More effective than this solution is caching master data within application layer without access to PL/SQL

CREATE OR REPLACE PACKAGE Cache_TableAlias AS
--------------------------------------------------------------------------------
-- Author : %derived_by: ramm %
-- Version : %version: 1 %
-- Last Change : %date_created: 2009/11/12 11:04:54 %
--
-- Description: Cachen von Daten der Tabelle innerhalb SQL-Session
-- Dient zum Abfangen von Mehrfach-Zugriffen / Hot-Blocks im NestedLoop
-- Initial verwendet für D3Art-Export.
-- Aktuell im RecordType nicht vorhandene Felder bitte nachruesten wenn noetig

-- Fehltreffer in der Tabelle (incl. NULL als Parameter) werden mit Exception beantwortet
-- Evtl. NULL-Handling der ID muss vor dem Aufruf der Funktionen gehandelt werden

-- Aktuell ist kein Schwellwert fuer Cache-Groesse implentiert.
-- Durch die Nutzer ist sicherzustellen, dass Nutzung des Cachings
-- nur im Rahmen des verfuegbaren Memory stattfindet (ca. < 10000 Records) !!!
-- Auf Implementierung Cache-Obergrenze wurde in Anbetracht der Mengen bewusst verzichtet,

-- Das begrenzte Alter der Cache-Inhalte dient dem gesicherten Refresh der Daten der SQL-Session
-- bei Verwendung von Session-Pooling.

-- Testen lässt sich die Funktion des Caches easy per Test des folgenden Stmt. auf leeres Result:
-- SELECT /*+ PARALLEL(m) */ * FROM SchemaAlias.TableAlias m
-- WHERE ColumnAlias != SchemaAlias.Cache_TableAlias.getColumnAliasByID(ID);
--------------------------------------------------------------------------------

TYPE CacheRecordType IS RECORD (
 ColumnAlias SchemaAlias.TableAlias.ColumnAlias%TYPE
);

-- Zugriff auf kompletten Record nach ID (nur anwendbar innerhalb PL/SQL)
FUNCTION getByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return CacheRecordType PARALLEL_ENABLE;

-- Zugriff auf einzelnes Feld des Records für Anwendung in SQL-Statements
FUNCTION getColumnAliasByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return SchemaAlias.TableAlias.ColumnAlias%TYPE PARALLEL_ENABLE;

END Cache_TableAlias;
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY Cache_TableAlias AS
 TYPE CacheTableType IS TABLE OF CacheRecordType INDEX BY BINARY_INTEGER; -- TableType zum Cachen der Inhalte
 COUNT_BEFORE_SYSDATE_CHECK CONSTANT NUMBER DEFAULT 1000; -- Anzahl Zugriffe bevor wieder mit SYSDATE Alter gepueft wird
 MAX_CACHE_AGE CONSTANT NUMBER DEFAULT 0.5; -- Max. Alter der Cache-Inhalt in Tagen
 v_CacheTable CacheTableType; -- Table zum Cachen der Inhalte
 v_LastRefreshDate DATE DEFAULT SYSDATE; -- Abgrenz-Zeitpunkt für Ausaltern der gecachten Werte
 v_Counter NUMBER DEFAULT 0; -- Counter für Hochzählen vor naechstem SYSDATE-Zugriff

 FUNCTION getByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return CacheRecordType PARALLEL_ENABLE IS
 BEGIN
 v_Counter := v_Counter + 1;
 IF v_Counter = COUNT_BEFORE_SYSDATE_CHECK THEN
 v_Counter := 0; -- Anzahl Zugriffe bis zu naechstem Alters-Check
 IF SYSDATE > v_LastRefreshDate + MAX_CACHE_AGE THEN
 v_LastRefreshDate := SYSDATE;
 v_CacheTable.DELETE;
 END IF;
 END IF;
 IF (NOT v_CacheTable.EXISTS(p_ID)) THEN -- Existiert der Cache-Eintrag noch nicht ?
 BEGIN
 SELECT /*+ "Package SchemaAlias.Cache_TableAlias" */ ColumnAlias
 INTO v_CacheTable(p_ID) 
 FROM SchemaAlias.TableAlias
 WHERE ID=p_ID
 ;
 EXCEPTION
 WHEN NO_DATA_FOUND THEN
 IF p_ID IS NULL THEN
 RAISE_APPLICATION_ERROR(-20099, 'Access to SchemaAlias.TableAlias with ID=NULL not supported', TRUE);
 ELSE
 RAISE_APPLICATION_ERROR(-20099, 'Record with ID='||p_ID||' does not exist in table SchemaAlias.TableAlias', TRUE);
 END IF;
 WHEN OTHERS THEN
 RAISE;
 END;
 END IF;
 RETURN v_CacheTable(p_ID);
 END getByID;

 -- Zugriff auf einzelnes Feld des Records für Anwendung in SQL-Statements
 FUNCTION getColumnAliasByID(p_ID SchemaAlias.TableAlias.ID%TYPE) return SchemaAlias.TableAlias.ColumnAlias%TYPE PARALLEL_ENABLE IS
 BEGIN
 RETURN getByID(p_ID).ColumnAlias;
 END getColumnAliasByID;

END Cache_TableAlias;
/
SHOW ERRORS;
