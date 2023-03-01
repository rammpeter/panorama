module PanoramaSampler::PackageConDbidFromConId
  # PL/SQL-Package for snapshot creation
  # panorama_owner is replaced by real schema owner
  def con_dbid_from_con_id_spec
    "
CREATE OR REPLACE PACKAGE panorama_owner.Con_DBID_From_Con_ID IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Init;

  /* Call from outside the package to ensure select on v$Containes gets valid result */
  PROCEDURE Learn(p_Con_ID IN NUMBER, p_Con_DBID IN NUMBER);

  FUNCTION Get(p_Con_ID IN NUMBER) RETURN NUMBER;
END Con_DBID_From_Con_ID;
    "
  end

  def con_dbid_from_con_id_body
    "
CREATE OR REPLACE PACKAGE BODY panorama_owner.Con_DBID_From_Con_ID IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
  TYPE Con_DBID_Table_Type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  Con_DBID_Table Con_DBID_Table_Type;

  PROCEDURE Init IS
  BEGIN
    Con_DBID_Table.DELETE;
  END Init;

  PROCEDURE Learn(p_Con_ID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
     Con_DBID_Table(p_Con_ID) := p_Con_DBID;
  END Learn;

  FUNCTION Get(p_Con_ID IN NUMBER) RETURN NUMBER IS
    #{"PRAGMA UDF;" if PanoramaConnection.db_version >= '12.1'}
  BEGIN
    IF NOT Con_DBID_Table.EXISTS(p_Con_ID) THEN
      RAISE_APPLICATION_ERROR(-20999, 'Con_DBID_From_Con_ID.Get: No Con_DBID available for Con_ID='||p_Con_ID||'! '||Con_DBID_Table.COUNT||' PDBs are known (including Con-ID=0)');
    END IF;
    RETURN Con_DBID_Table(p_Con_ID);
  END Get;

END Con_DBID_From_Con_ID;
    "
  end

end