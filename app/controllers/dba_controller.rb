# encoding: utf-8
class DbaController < ApplicationController

  include DbaHelper

  def list_dml_locks
    show_all_locks = params[:show_all_locks]
    
    @max_result_size = params[:max_result_size].to_i

    @dml_locks = sql_select_all(["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (
              SELECT /*+ ORDERED */
                RowNum                                                      ,
                l.Inst_ID                                                   Instance_Number,
                s.SID,
                s.Serial#                                                   SerialNo,
                s.SQL_ID, s.SQL_Child_Number,
                s.Prev_SQL_ID, s.Prev_Child_Number, l.Inst_ID,
                s.Status                                                    Status,
                s.Client_Info, s.Module, s.Action,
                LOWER(lo.Owner)                                             Locked_Object_Owner,
                lo.Object_Name                                              Locked_Object_Name,
                lo.SubObject_Name                                           Locked_SubObject_Name,
                lo.Object_Type                                              Locked_Object_Type,
                x.XIDUSN                                                    Rollback_Segment,
                s.Inst_ID||':'||p.spID||':'||s.UserName                     InstPIDUser,
                s.machine||'('||s.OSUser||'):'||s.Process||':'||s.program   MaschinePIDProgFull,
                SUBSTR(s.machine||'('||s.OSUser||'):'||s.Process||':'||s.program,1,20) MaschinePIDProg,
                l.Type                                                      LockType,
                CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN   /* Waiting for Lock */
                    o.Owner||'.'||o.Object_Name
                END                                                         WaitingForObject,
                o.Data_Object_ID,
                s.Row_Wait_File#                                            Row_Wait_File_No,
                s.Row_Wait_Block#                                           Row_Wait_Block_No,
                s.Row_Wait_Row#                                             Row_Wait_Row_No,
                s.Seconds_In_Wait                                           WaitingForTime,
                l.ctime                                                     Lock_Held_Seconds,
                SUBSTR(l.ID1||':'||l.ID2,1,12)                              ID1ID2,
                /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                TO_CHAR(l.Request)                                          Request,
                TO_CHAR(l.lmode)                                            LockMode,
                RowNum      /* fuer Ajax-Aktualisierung der Zeile */        Row_Num,
               bs.Inst_ID             Blocking_Instance_Number,
               bs.SID                 Blocking_SID,
               bs.Serial#             Blocking_SerialNo
              FROM    gv$lock l
              JOIN    gv$session s              ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
              JOIN    GV$Process p              ON p.Inst_ID = s.Inst_ID AND p.Addr = s.pAddr
              LEFT OUTER JOIN gv$Session bs     ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
              LEFT OUTER JOIN DBA_Objects lo    ON lo.Object_ID = l.ID1  -- locked object
              LEFT OUTER JOIN gv$Transaction x  ON x.Inst_ID = s.Inst_ID AND x.Addr = s.TAddr
              -- Join über dem Wait bekanntes Object, alternativ über der session bekanntes Objekt auf das gewartet wird
              -- Bei Request = 3 enthaelt row_wait_obj# zuweilen das vorherige Objekt statt des aktuellen, in dem Falle ist auch die RowID Murks
              LEFT OUTER JOIN DBA_Objects o     ON o.Object_ID = DECODE(s.P2Text, 'object #', s.P2, DECODE(s.Row_Wait_Obj#, -1, NULL, s.Row_Wait_Obj#))  -- Objekt, auf das gewartet wird wenn existiert
              WHERE   s.type          = 'USER'
            )
      #{show_all_locks ? "" : " WHERE LockType NOT IN ('AE', 'PS') "  }  -- Type-Filter ausserhalb des Selects weil sonst auf Exadata/11g utopische Laufzeiten wegen Cartesian Join
      ORDER BY Inst_ID, SID, Locked_Object_Name
      "])
    @result_size = @dml_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    @dml_locks.delete_at(@dml_locks.length-1) while @dml_locks.length > @max_result_size 

    @dist_locks = sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             Local_Tran_ID,
             Global_tran_ID,
             State, Mixed, Advice, Tran_Comment,
             Fail_Time, Force_Time, Retry_Time,
             OS_User, OS_Terminal, Host, DB_User,
             Commit# Commit_No
      FROM   DBA_2PC_Pending"

    respond_to do |format|
      format.js {render :js => "$('#list_locks_area').html('#{j render_to_string :partial=>"list_dml_locks" }');"}
    end
  end # list_dml_locks

  def list_blocking_dml_locks

    @locks = sql_select_all "\
      WITH Locks AS (
              SELECT /*+ LEADING(l) */ /* Panorama-Tool Ramm */
                     l.Inst_ID,
                     s.SID,
                     s.Serial# SerialNo,
                     s.SQL_ID,
                     s.SQL_Child_Number,
                     s.Status, s.Event,
                     s.Client_Info,
                     s.Module,
                     s.Action,
                     CASE
                     WHEN l.Type='TM' THEN /* Locked Object for TM */
                          (SELECT o.Owner||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
                     WHEN l.Type='TX' THEN /* Used Rollback Segment for TX */
                          (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV$Transaction x WHERE x.Addr=s.TAddr)
                     END ObjectName,
                     s.UserName,
                     s.machine,
                     s.OSUser,
                     s.Process,
                     s.program,
                     l.Type LockType,
                     bo.Owner               Blocking_Object_Schema,
                     bo.Object_Name         Blocking_Object_Name,
                     bo.SubObject_Name      Blocking_SubObject_Name,
                     bo.Data_Object_ID,
                     s.Row_Wait_File#       Row_Wait_File_No,
                     s.Row_Wait_Block#      Row_Wait_Block_No,
                     s.Row_Wait_Row#        Row_Wait_Row_No,
                     s.Seconds_In_Wait,
                     l.ID1,
                     l.ID2,
                     /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                     l.Request Request,
                     l.lmode   LockMode,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_SerialNo,
                     bs.Status              Blocking_Status,
                     bs.Event               Blocking_Event,
                     bs.Client_Info         Blocking_Client_Info,
                     bs.Module              Blocking_Module,
                     bs.Action              Blocking_Action,
                     bs.UserName            Blocking_UserName,
                     bs.Machine             Blocking_Machine,
                     bs.OSUser              Blocking_OSUser,
                     bs.Process             Blocking_Process,
                     bs.Program             Blocking_Program
               FROM gv$lock l
               JOIN gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
               LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
               -- Object der blockenden Session
               LEFT OUTER JOIN sys.DBA_Objects bo ON bo.Object_ID = CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 THEN /* Waiting for Lock */
                                                                         CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Objekt */ s.P2
                                                                         ELSE CASE WHEN s.Row_Wait_Obj# != -1 THEN /* Session kennt Objekt */   s.Row_Wait_Obj#
                                                                              ELSE NULL
                                                                              END
                                                                         END
                                                                    END
               WHERE s.type = 'USER'
               AND   l.Type != 'PS'
               AND   s.LockWait IS NOT NULL
               AND   l.Request  != 0
              ),
      HLocks AS (
              SELECT /*+ NO_MERGE */ RowNum Row_Num, Level HLevel, l.*,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serialno = blocking_serialNo
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.SerialNo = l.SerialNo
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num"

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    respond_to do |format|
      format.js {render :js => "$('#list_locks_area').html('#{j render_to_string :partial=>"list_blocking_dml_locks" }');"}
    end
  end

  def convert_to_rowid
    @waitingforobject = params[:waitingforobject] # schema.objectname

    @rowid = sql_select_one ["SELECT RowIDTOChar(DBMS_RowID.RowID_Create(1, ?, ?, ?, ?)) FROM DUAL",
                             params[:data_object_id].to_i,
                             params[:row_wait_file_no].to_i,
                             params[:row_wait_block_no].to_i,
                             params[:row_wait_row_no].to_i
                            ]
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_rowid_link"  }');"}
    end
  end

  # Anzeige der ApplInfo auf Basis der Client_Info aus v$session
  def explain_info
    @info = params[:info]
    @update_area = params[:update_area]

    res = explain_application_info(@info)
    if res[:short_info]
      res_string = "#{res[:short_info]} : #{res[:long_info]}"
    else
      res_string = "No info available"
    end

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :text=>res_string}');"}
    end
  end

  def list_ddl_locks

    #@max_result_size = params[:max_result_size].to_i

    @ddl_locks = sql_select_all("\
      SELECT /*+ ordered */ /* Panorama-Tool Ramm */
        h1.Inst_ID                                                  B_Inst_ID,
        h1.SID                                                      B_SID,
        h1.Serial#                                                  B_SerialNo,
        p1.spID                                                     B_PID,
        h1.UserName                                                 B_User,
        h1.Machine                                                  B_Machine,
        h1.OSUser                                                   B_OSUser,
        h1.Process                                                  B_Process,
        h1.Program                                                  B_Program,
        w1.Inst_ID                                                  W_Inst_ID,
        w1.SID                                                      W_SID,
        w1.Serial#                                                  W_SerialNo,
        w.kgllktype                                                 LockType,
        SUBSTR(od.TO_Name,1,30)                                     Object,
        decode(h.kgllkmod,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_held,
        decode(w.kgllkreq,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_requested
      FROM  dba_kgllock w,
            dba_kgllock h,
            GV$session w1,
            GV$session h1,
            GV$Process p1,
            v$Object_dependency od
      WHERE   (((h.kgllkmod != 0)     and (h.kgllkmod != 1)
      and     ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
      and     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
      and     ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
      and     w.kgllktype             = h.kgllktype
      and     w.kgllkhdl              = h.kgllkhdl
      and     w.kgllkuse              = w1.saddr
      and     h.kgllkuse              = h1.saddr
      AND     od.TO_ADDRESS           = w.kgllkhdl
      AND     p1.Addr                 = h1.pAddr
      AND     p1.Inst_ID              = h1.Inst_ID
      ")

    #@result_size = @ddl_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    #@ddl_locks.delete_at(@ddl_locks.length-1) while @ddl_locks.length > @max_result_size
    respond_to do |format|
      format.js {render :js => "$('#list_locks_area').html('#{j render_to_string :partial=>"list_ddl_locks" }');"}
    end
  end # list_ddl_locks

  # Extrahieren des PKey und seines Wertes für RowID
  def show_rowid_details
    waitingforobject = params[:waitingforobject]               # schema.Tablename
    schema    = waitingforobject[0,waitingforobject.index(".")]   # extrahierter Schema-name
    object_name = waitingforobject[waitingforobject.index(".")+1,waitingforobject.length] # extrahierter Object-Name
    rowid     = params[:waitingforrowid]

    object_rec = sql_select_all(["\
                   SELECT Object_Type Object_Type
                   FROM   All_Objects
                   WHERE  Owner = UPPER(?)
                   AND    Object_Name = UPPER(?)",
                   schema, object_name])[0]

    raise "No object found with name #{waitingforobject}" unless object_rec

    if object_rec.object_type.match("INDEX")
      table_name = sql_select_all(["\
                     SELECT Table_Name
                     FROM   All_Indexes
                     WHERE  Owner = UPPER(?)
                     AND    Index_Name = ?",
                     schema, object_name])[0].table_name
    else
      table_name = object_name
    end

    pstmt = sql_select_all("\
             SELECT Column_Name                                              
             FROM   All_Ind_Columns                                          
             WHERE  Index_Owner   = UPPER('"+schema+"')                      
             AND    Index_Name =                                             
                    (SELECT Index_Name                                       
                     FROM   All_Constraints                                  
                     WHERE  Owner      = UPPER('"+schema+"')                 
                     AND    Table_Name = UPPER('"+table_name+"')
                     AND    Constraint_Type = 'P'                            
                    )")
    raise "Kein Primary Key gefunden für Object '#{schema}.#{object_name} / Tabelle #{table_name}" if pstmt.length == 0

    # Ermittlung der Primary-Key-Spalten der Tabelle
    pkey_cols = ""
    first = true
    pstmt.each do |s| 
      if first
        first = false
      else
        pkey_cols << ", "
      end
      pkey_cols << s.column_name
    end

    pkey_sql = "SELECT #{pkey_cols} Line FROM #{schema}.#{table_name} WHERE RowID=?"
    pkey_vals = sql_select_all([pkey_sql, rowid])
    raise "Keine Daten gefunden für SQL: #{pkey_sql}" if pkey_vals.length == 0

    result = "Tabelle #{table_name}, PKey (#{pkey_cols}) = '#{pkey_vals[0].line}'"

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j result }');"}
    end
  end # show_lock_details

  def show_redologs
    @redologs = sql_select_all("\
      SELECT /* NOA-Tools Ramm */
        Inst_ID,
        TO_CHAR(Group#) GroupNo,                                
        (Bytes/1024) KByte,                                     
        Status,                                                 
        TO_CHAR(First_Time,'#{sql_datetime_second_mask}') StartTime,
        Members, Archived
      FROM gV$LOG
      WHERE Inst_ID = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# getzeigt, dies verhindert die Dopplung
    ORDER BY First_Time DESC")
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/show_redologs" }');"}
    end
  end # show_redologs

  def list_redologs_historic
    @instance = prepare_param_instance
    @dbid     = prepare_param_dbid
    save_session_time_selection  # werte in session puffern

    wherestr = ""
    whereval = []

    if @instance
      wherestr << " AND l.Instance_Number = ?"
      whereval << @instance
    end

    @redologs = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ ss.Begin_Interval_Time, l.*
      FROM   (
              SELECT DBID, Snap_ID, Instance_Number, COUNT(*) Log_Number,
                     SUM(CASE WHEN Archived='NO' THEN 1 ELSE 0 END) Not_Archived,
                     SUM(CASE WHEN Status='CURRENT' THEN 1 ELSE 0 END) Current_No,
                     SUM(CASE WHEN Status='ACTIVE' THEN 1 ELSE 0 END) Active_no
              FROM   DBA_Hist_Log
              WHERE  DBID = ?
              AND Instance_Number = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# getzeigt, dies verhindert die Dopplung
              GROUP BY DBID, Snap_ID, Instance_Number
             ) l
      JOIN   DBA_Hist_Snapshot ss ON ss.DBID=l.DBID AND ss.Snap_ID=l.Snap_ID AND ss.Instance_Number=l.Instance_Number
      WHERE  ss.Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      AND    ss.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') #{wherestr}
      ORDER BY ss.Begin_Interval_Time, l.Instance_Number
      ", @dbid, @time_selection_start, @time_selection_end].concat whereval


    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=> "list_redologs_historic"}');"}
    end
  end

  def oracle_parameter
    begin
      @parameters = sql_select_all("\
        SELECT /* Panorama-Tool Ramm */
          i.Instance_Number                 Instance,  -- Daten koennen nur on aktueller Instance gezogen werden
          X$KSPPI.INDX                      ID,
          X$KSPPI.KSPPITY                   ParamType,
          X$KSPPI.KSPPINM                   Name,
          X$KSPPI.KSPPDESC                  Description,
          X$KSPPSV.KSPPSTVL                 Value,
          NULL /* X$KSPPSV.ksppstdvl */     Display_Value, -- existiert ab 11g nicht mehr in dem View
          X$KSPPSV.KSPPSTDF                 IsDefault
        FROM  X$KSPPI
        JOIN  X$KSPPSV ON X$KSPPSV.INDX = X$KSPPI.INDX
        CROSS JOIN  V$Instance i
        ORDER BY 3 ASC")
    rescue Exception
      @hint = "Möglicherweise fehlende Zugriffsrechte auf Tabellen X$KSPPI und X$KSPPSV !</br>
  Es werden deshalb nur die documented Parameter aus GV$Parameter angezeigt.</br></br>

  Lösung: Exec als User 'SYS':</br>
    create view X_$KSPPI as select * from X$KSPPI;</br>
    grant select on X_$KSPPI to public;</br>
    create public synonym X$KSPPI for sys.X_$KSPPI;</br></br>

    create view X_$KSPPSV as select * from X$KSPPSV;</br>
    grant select on X_$KSPPSV to public;</br>
    create public synonym X$KSPPSV for sys.X_$KSPPSV;
  ".html_safe
      @parameters = sql_select_all("\
        SELECT /* Panorama-Tool Ramm */
          Inst_ID                Instance,
          Num                    ID,
          Type                   ParamType,
          Name,
          Description,
          Value, Display_Value,
          IsDefault
        FROM  gv$Parameter
        ORDER BY Name, Inst_ID")
    end

    @parameters.each do |p|
      p.value = p.value + " (Caution!!! This is session setting of Panorama-Session! Database default may differ! Use sqlplus with SELECT * FROM gv$Parameter WHERE name='cursor_sharing'; to read real defaults.)" if p.name == "cursor_sharing"
    end

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/oracle_parameter" }');"}
    end
  end # oracle_parameter


  # Nutzung von Datafiles
  def datafile_usage
    @datafiles = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
             d.*,
             NVL(f.BYTES,0)/1048576            MBFree,
             (d.BYTES-NVL(f.BYTES,0))/1048576  MBUsed,
             d.BYTES/1048576                   FileSize,
             (d.Bytes-NVL(f.Bytes,0))/d.BYTES  PctUsed
      FROM   (SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, Online_Status
              FROM   DBA_Data_Files
              UNION ALL
              SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, '[UNKNOWN]' Online_Status
              FROM   DBA_Temp_Files
             )d
      LEFT JOIN (SELECT File_ID, Tablespace_Name, SUM(Bytes) Bytes
                 FROM   DBA_FREE_SPACE
                 GROUP BY File_ID, Tablespace_Name
                ) f ON f.FILE_ID = d.FILE_ID AND f.Tablespace_Name = d.Tablespace_Name -- DATA und Temp verwenden File_ID redundant
      ORDER BY 1 ASC")

    if session[:database].version >= "11.2"
      @file_usage = sql_select_all "\
        SELECT f.*,
               NVL(d.File_Name, t.File_Name) File_Name,
               NVL(d.Tablespace_Name, t.Tablespace_Name) Tablespace_Name
        FROM   gv$IOStat_File f
        LEFT JOIN DBA_Data_Files d ON d.File_ID = f.File_No AND f.FileType_Name='Data File'   -- DATA und Temp verwenden File_ID redundant
        LEFT JOIN DBA_Temp_Files t ON t.File_ID = f.File_No AND f.FileType_Name='Temp File'
        ORDER BY f.Inst_ID, f.File_No
      "
    end

    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/datafile_usage" }');"}
    end
  end


  # Aktuell genutzt Objekte
  def used_objects
    @objects = sql_select_all("\
      SELECT /* NOA-Tools Ramm */
             a.Inst_ID,
             a.SID, 
             s.SERIAL# sn, 
             a.OBJECT, 
             a.TYPE ObjectType, 
             s.STATUS, 
             s.OSUSER, 
             s.PROCESS, 
             s.MACHINE,
             s.PROGRAM, 
             s.LOGON_TIME
      FROM gV$ACCESS a INNER JOIN gV$SESSION s ON a.SID = s.SID AND a.Inst_ID = s.Inst_ID
      ORDER BY 1 ASC")
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/used_objects" }');"}
    end
  end

  # Latch-Waits wegen cache buffers chains
  def latch_cache_buffers_chains
    @waits = sql_select_all("\
      SELECT /*+ FIRST_ROWS */ /* NOA-Tools Ramm */               
        ln.Name,                                                  
        o.Owner,                                                  
        o.Object_Name,                                            
        sw.p3 Tries,                                              
        b.tch Touches,                                            
        TO_CHAR(sw.p1) LatchAddr,                                 
        b.dbablk BlockNo                                          
      FROM  v$session_wait sw,                                    
            v$latchname ln,                                       
            X$bh b,                                               
            dba_objects o                                         
      WHERE sw.Event = 'latch: cache buffers chains'              
      AND   ln.Latch# = sw.p2                                     
      AND   ln.name   = 'cache buffers chains'                    
      AND   b.hladdr=sw.p1raw                                     
      AND   o.object_id = b.obj                                   
      ORDER BY 1 ASC")
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/latch_cache_buffers_chains" }');"}
    end
  rescue Exception => ex; alert ex, "
Möglicherweise fehlende Zugriffsrechte auf Table X$BH! Lösung: Exec als User 'SYS':
> create view x_$bh as select * from x$bh;
> grant select on x_$bh to public;
> create public synonym x$bh for sys.x_$bh;

                                "
  end

  # Waits wegen db_file_sequential_read
  def wait_db_file_sequential_read
    @waits = sql_select_all "\
      SELECT /* NOA-Tools Ramm */                                 
        w.SID,                                                    
        w.Seq# SerialNo,                                          
        Wait_Time,                                                
        Seconds_In_Wait,                                          
        State,                                                    
        (SELECT SEGMENT_TYPE||':'||SEGMENT_NAME                   
        FROM DBA_Extents e                                        
        WHERE e.File_ID = w.P1                                    
        AND w.p2 BETWEEN e.BLOCK_ID AND e.BLOCK_ID + e.BLOCKS -1  
        ) name                                                    
      FROM V$Session_Wait w                                       
      WHERE Event='db file sequential read'                       
      ORDER BY 1 ASC"
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/wait_db_file_sequential_read" }');"}
    end
  end
  
  def list_sessions
    @instance  = prepare_param_instance
    where_string = ""
    where_values = []
    if @instance
      where_string << " AND s.Inst_ID = ?"
      where_values << @instance
    end
    if params[:showOnlyUser]=="1"
      where_string << " AND s.type = 'USER'"
    end
    if params[:showPQServer]!="1"
      where_string << " AND (s.Program IS NULL OR INSTR(s.Program, '(P0')=0)"
    end
    if params[:onlyActive]=="1"
      where_string << " AND s.Status='ACTIVE'"
    end
    if params[:showOnlyDbLink]=="1"
      where_string << " AND UPPER(s.program) like 'ORACLE@%' AND UPPER(s.Program) NOT LIKE 'ORACLE@'||(SELECT UPPER(i.Host_Name) FROM gv$Instance i WHERE i.Inst_ID=s.Inst_ID)||'%' "
    end
    if params[:filter] && params[:filter] != ""
      where_string << " AND ("
      where_string << "    TO_CHAR(s.SID)     LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR TO_CHAR(s.Process) LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR TO_CHAR(p.spid)    LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR s.UserName         LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR s.OSUser           LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR s.Machine          LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << ")"
    end

    @sessions = sql_select_all ["\
      SELECT /* NOA-Tools Ramm */                                                                                                         
        s.SID||','||s.Serial# SidSn,
        s.SID,
        s.Serial# SerialNo,                                                                                          
        s.Status,                                                                                                                         
        s.Inst_ID,                                                                                                                        
        s.UserName,                 
        s.Client_Info,
        s.Module, s.Action,
        p.spID,                                                                                                                           
        s.machine,                                                                                                                        
        s.OSUser,                                                                                                                         
        s.Process,                                                                                                                        
        s.program,
        s.Service_Name,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        s.Logon_Time,
        i.Block_Gets+i.Consistent_Gets+i.Physical_Reads+i.Block_Changes+i.Consistent_Changes IOIndex,
        temp.Temp_MB, temp.Temp_Extents, temp.Temp_Blocks,
        (       SELECT TO_CHAR(MIN(Start_Time), 'HH24:MI:SS') FROM GV$Session_LongOps o                                                   
                WHERE   o.SID                   = s.SID                 /* Referenz auf Session */                                        
                AND     o.Serial#               = s.Serial#             /* Referenz auf Session */                                        
                AND     o.SQL_Address           = s.SQL_Address         /* Referenz auf aktuelles Stmt, kann mehrfach ausgefuert worden sein */ 
                AND     o.SQL_Hash_Value        = s.SQL_Hash_Value      /* Referenz auf aktuelles Stmt, kann mehrfach ausgefuert worden sein */ 
                /* Vom Aktuellen Stmt aelteste Aktion nur zeigen, wenn kein anderes Stmt zwischendurch ausgefuehrt wurde */               
                AND     NOT EXISTS (SELECT '!' FROM GV$Session_LongOpS o1                                                                 
                                WHERE   o1.SID                  = o.SID                                                                   
                                AND     o1.Serial#              = o.Serial#                                                               
                                AND     o1.SQL_Address          != o.SQL_Address                                                          
                                AND     o1.SQL_Hash_Value       != o.SQL_Hash_Value                                                       
                                AND     o1.Last_Update_Time     > o.Last_Update_Time                                                      
                                )                                                                                                         
        )       LongSQL,
        px.Anzahl PQCount,
        pqc.QCInst_ID, pqc.QCSID, pqc.QCSerial# QCSerialNo,
        p.PGA_Used_Mem     + NVL(pq_mem.PQ_PGA_Used_Mem,0)     PGA_Used_Mem,
        p.PGA_Alloc_Mem    + NVL(pq_mem.PQ_PGA_Alloc_Mem,0)    PGA_Alloc_Mem,
        p.PGA_Freeable_Mem + NVL(pq_mem.PQ_PGA_Freeable_Mem,0) PGA_Freeable_Mem,
        p.PGA_Max_Mem      + NVL(pq_mem.PQ_PGA_Max_Mem,0)      PGA_Max_Mem,
        Open_Cursor, Open_Cursor_SQL,
        wa.Operation_Type, wa.Policy, wa.Active_Time_Secs, wa.Work_Area_Size_MB,
        wa.Expected_Size_MB, wa.Actual_Mem_Used_MB, wa.Max_Mem_Used_MB, wa.Number_Passes,
        wa.WA_TempSeg_Size_MB
      FROM    GV$session s
      JOIN    (SELECT Inst_ID, SID, count(*) Open_Cursor, count(distinct sql_id) Open_Cursor_SQL
               FROM   gv$Open_Cursor
               GROUP BY Inst_ID, SID
              ) oc ON oc.Inst_ID = s.Inst_ID AND oc.SID = s.SID
      LEFT OUTER JOIN ( SELECT px.QCInst_ID, px.QCSID, px.QCSerial#, Count(*) Anzahl FROM GV$PX_Session px
                       GROUP BY px.QCInst_ID, px.QCSID, px.QCSerial#
                      ) px ON  px.QCInst_ID = s.Inst_ID
                           AND px.QCSID     = s.SID
                           AND px.QCSerial# = s.Serial#
      LEFT OUTER JOIN GV$PX_Session pqc ON pqc.Inst_ID = s.Inst_ID AND pqc.SID=s.SID AND pqc.Serial#=s.Serial#    -- PQ Coordinator
      JOIN    GV$sess_io i ON i.Inst_ID = s.Inst_ID AND i.SID = s.SID
      JOIN    GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
      LEFT OUTER JOIN
              ( SELECT  DECODE(QCInst_ID, NULL, Inst_ID, QCinst_ID) Inst_ID,
                        DECODE(QCSID,NULL, SID, QCSID)  SID,
                        MIN(Operation_Type)             Operation_Type,
                        MIN(Policy)                     Policy,
                        MAX(Active_Time)/1000000        Active_Time_Secs,
                        SUM(Work_Area_Size)/(1024*1024) Work_Area_Size_MB,
                        SUM(Expected_Size)/(1024*1024)  Expected_Size_MB,
                        SUM(Actual_Mem_Used)/(1024*1024) Actual_Mem_Used_MB,
                        SUM(Max_Mem_Used)/(1024*1024)   Max_Mem_Used_MB,
                        MAX(Number_Passes)              Number_Passes,
                        SUM(TempSeg_Size)/(1024*1024)   WA_TempSeg_Size_MB,
                        COUNT(*)                        Anzahl
                FROM    gv$sql_workarea_active
                GROUP BY DECODE(QCInst_ID, NULL, Inst_ID, QCinst_ID),
                         DECODE(QCSID,NULL, SID, QCSID)
              ) wa ON wa.Inst_ID = s.Inst_ID AND wa.SID = s.SID
      LEFT OUTER JOIN
             (        -- PGA-Speicher möglicher PQ-Server. für die akt. Session Query-Coordinator ist
             SELECT px.QCInst_ID, px.QCSID, px.QCSerial#,
                    SUM(PGA_Used_Mem)     PQ_PGA_Used_Mem,
                    SUM(PGA_Alloc_Mem)    PQ_PGA_Alloc_Mem,
                    SUM(PGA_Freeable_Mem) PQ_PGA_Freeable_Mem,
                    SUM(PGA_Max_Mem)      PQ_PGA_Max_Mem
             FROM GV$PX_Session px
             JOIN GV$Session pqs ON pqs.Inst_ID = px.Inst_ID AND pqs.SID = px.SID
             JOIN gv$process pqp ON pqp.Inst_ID = px.inst_ID AND pqp.Addr = pqs.pAddr
             GROUP BY px.QCInst_ID, px.QCSID, px.QCSerial#
             ) pq_mem ON pq_mem.qcinst_id = s.Inst_ID AND pq_mem.QCSID = s.SID AND pq_mem.QCSerial# = s.Serial#
      LEFT OUTER JOIN
             (SELECT Inst_ID, Session_Addr, SUM(Extents) Temp_Extents, SUM(Blocks) Temp_Blocks, SUM(Blocks)*#{session[:database].db_block_size}/(1024*1024) Temp_MB
              FROM   gv$Sort_Usage
              GROUP BY Inst_ID, Session_Addr
             ) temp ON temp.Inst_ID = s.Inst_ID AND temp.Session_Addr = s.sAddr
      WHERE 1=1 #{where_string}
      ORDER BY 1 ASC"].concat(where_values)

    respond_to do |format|
      format.js {render :js => "$('#list_sessions_area').html('#{j render_to_string :partial=>"list_sessions" }');"}
    end
  end
  
  def show_session_detail
    @instance    =  prepare_param_instance
    @sid         =  params[:sid].to_i
    @serialno    = params[:serialno].to_i
    @update_area = params[:update_area]

    @dbsessions =  sql_select_all ["\
           SELECT s.SQL_ID, s.Prev_SQL_ID, RawToHex(s.SAddr) SAddr,
                  s.SQL_Child_Number, s.Prev_Child_Number,
                  s.Status, s.Client_Info, s.Module, s.Action, s.AudSID,
                  s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                  SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                  s.Logon_Time, p.spID
           FROM   GV$Session s
           JOIN   GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
           WHERE  s.Inst_ID=? AND s.SID=? AND s.Serial#=?",
           @instance, params[:sid], params[:serialno] ]
    @dbsession    = nil
    @current_sql  = nil
    @previous_sql = nil
    if @dbsessions.length > 0   # Session lebt noch
      @dbsession = @dbsessions[0]
      @current_sql  = get_sga_sql_statement(@instance, @dbsession.sql_id)       if @dbsession.sql_id
      @previous_sql = get_sga_sql_statement(@instance, @dbsession.prev_sql_id)  if @dbsession.prev_sql_id
    end

    @pq_coordinator = sql_select_all ["SELECT s.Inst_ID, s.SID, s.Serial# SerialNo,
                                              s.SQL_ID, s.SQL_Child_Number, s.Status, s.Client_Info, s.Module, s.Action,
                                              s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                                              SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                                              s.Logon_Time, p.spID
                                       FROM   gv$PX_Session ps
                                       JOIN   gv$Session s ON s.Inst_ID = ps.QCInst_ID AND s.SID = ps.QCSID AND s.Serial# = ps.QCSerial#
                                       JOIN   GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
                                       WHERE  ps.Inst_ID = ?
                                       AND    ps.SID     = ?
                                       AND    ps.Serial# = ?
                                      ", @instance, @sid, @serialno]

puts @pq_coordinator.class.name
puts @pq_coordinator.count

    @open_cursor_counts = sql_select_first_row ["\
                         SELECT /*+ ORDERED USE_HASH(s) */
                                COUNT(*) Total,
                                SUM(CASE WHEN oc.SAddr=se.SAddr THEN 1 ELSE 0 END) Own_SAddr
                         FROM   GV$Session se
                         JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID AND oc.SID     = se.SID
                         WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
                         ", @instance, @sid, @serialno]

    @pmems = sql_select_all ["\
            SELECT /*+ ORDERED USE_HASH(s p pm) */ pm.Category, 
                   SUM(pm.Allocated) Allocated,
                   SUM(pm.Used) Used,
                   SUM(pm.Max_Allocated) Max_Allocated
            FROM   (SELECT ? Inst_ID, ? SID, ? Serial# FROM DUAL
                    UNION ALL
                    SELECT Inst_ID, SID, Serial#
                    FROM   GV$PX_Session px
                    WHERE  px.QCInst_ID = ?
                    AND    px.QCSID     = ?
                    AND    px.QCSerial# = ?
                  ) x
            JOIN   GV$Session s ON s.Inst_ID = x.Inst_ID AND s.SID = x.SID AND s.serial# = x.Serial#
            JOIN   GV$Process p ON p.Inst_ID = s.Inst_ID AND p.Addr = s.pAddr
            JOIN   GV$Process_Memory pm ON pm.Inst_ID = p.Inst_ID AND pm.PID = p.PID AND pm.Serial# = p.Serial#
            GROUP BY pm.Category
            ", @instance, @sid, @serialno, @instance, @sid, @serialno]


    respond_to do |format|
      if @dbsession
        format.js {render :js => "$('##{@update_area}').html('#{j render_to_string :partial=>"list_session_details" }');"}
      else
        format.js {render :js => "$('##{@update_area}').html('#{j "<h2>Session ist nicht mehr existent</h2>".html_safe }');"}
      end
    end
  end

  def list_open_cursor_per_session
    @instance =  prepare_param_instance
    @sid     =  params[:sid].to_i
    @serialno = params[:serialno].to_i

    @opencursors = sql_select_all ["
      SELECT /*+ ORDERED USE_HASH(s wa) */ oc.SQL_ID oc_SQL_ID, oc.SQL_Text, wa.*,
             CASE WHEN se.SAddr = oc.SAddr THEN 'YES' ELSE 'NO' END Own_SAddr,
             sse.SID SAddr_SID, sse.Serial# SAddr_SerialNo
      FROM   GV$Session se
      JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID
                              AND oc.SID     = se.SID
      LEFT OUTER JOIN (SELECT Inst_ID, Address, Hash_Value,
                               SUM(Estimated_Optimal_Size)  Estimated_Optimal_Size,
                               SUM(Estimated_OnePass_Size)  Estimated_OnePass_Size,
                               SUM(Last_Memory_used)        Last_Memory_Used,
                               SUM(Active_Time)             Active_Time,
                               SUM(Max_TempSeg_Size)        Max_TempSeg_Size,
                               SUM(Last_TempSeg_Size)       Last_TempSeg_Size
                       FROM   gv$SQL_Workarea
                       GROUP BY Inst_ID, Address, Hash_Value
                      ) wa ON wa.Inst_ID    = oc.Inst_ID
                          AND wa.Address    = oc.Address
                          AND wa.Hash_Value = oc.Hash_Value
      LEFT OUTER JOIN gv$Session sse ON sse.Inst_ID = oc.Inst_ID AND sse.SAddr = oc.SAddr
      WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
      ", @instance, @sid, @serialno]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_open_cursor_per_session" }');"}
    end
  end

  def show_session_details_waits
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serialno = params[:serialno]

    @waits =  sql_select_all ["\
      SELECT w.Inst_ID, w.SID, w.Event,
             w.P1Text, w.P1, w.P1Raw,
             w.P2Text, w.P2, w.P2Raw,
             w.P3Text, w.P3, w.P3Raw,
             w.wait_Class,
             w.Seconds_In_Wait,
             w.State
      FROM   GV$Session_Wait w
      WHERE  w.Inst_ID = ?
      AND    w.SID     = ?
      ", @instance, @sid]

    @pq_waits =  sql_select_all ["\
      SELECT s.Program,
             px.Inst_ID,
             px.SID,
             px.req_degree,
             px.degree,
             w.Event,
             w.P1Text, w.P1, w.P1Raw,
             w.P2Text, w.P2, w.P2Raw,
             w.P3Text, w.P3, w.P3Raw,
             w.wait_Class,
             w.Seconds_In_Wait,
             w.State
      FROM   GV$PX_Session px,
             GV$Session s,
             GV$Session_Wait w
      WHERE  px.QCInst_ID = ?
      AND    px.QCSID     = ?
      AND    s.Inst_ID    = px.Inst_ID
      AND    s.SID        = px.SID
      AND    s.Serial#    = px.serial#
      AND    w.Inst_ID(+) = px.Inst_ID
      AND    w.SID(+)     = px.SID
      ", @instance, @sid]
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_session_details_waits" }');"}
    end
  end

  def show_session_details_locks
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serialno = params[:serialno]

    @locks =  sql_select_all ["\
      SELECT /*+ ORDERED */ /* Panorama-Tool Ramm */
        RowNum,
        CASE                                                                                    
          WHEN l.Type='TM' THEN         /* Locked Object for TM */                              
            (SELECT LOWER(o.Owner)||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
          WHEN l.Type='TX' THEN         /* Used Rollback Segment for TX */                      
            (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV\$Transaction x WHERE x.Addr=s.TAddr)  
        END                                                         Object,                     
        l.Type                                                      LockType,                   
        CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN   /* Waiting for Lock */      
            LOWER(o.Owner)||'.'||o.Object_Name
        END                                                         WaitingForObject,           
        CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 AND s.Row_Wait_Obj# != -1  THEN     
          RowIDTOChar(DBMS_RowID.RowID_Create(1, o.Data_Object_ID, s.Row_Wait_File#, s.Row_Wait_Block#, s.Row_Wait_Row#))
        END                                                         WaitingForRowID,             
        l.ctime Seconds_In_Lock,
        l.ID1, l.ID2,
        /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */                 
        TO_CHAR(l.Request)                                          Request,                    
        TO_CHAR(l.lmode)                                            LockMode,
        bs.Inst_ID             Blocking_Instance_Number,
        bs.SID                 Blocking_SID,
        bs.Serial#             Blocking_SerialNo
      FROM    gv$lock l
      JOIN    gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
      LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
      -- Join über der session bekanntes Objekt auf das gewartet wird, alternativ über dem Wait bekanntes Objekt
      LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = DECODE(s.Row_Wait_Obj#, -1, DECODE(s.P2Text, 'object #', s.P2, NULL), s.Row_Wait_Obj#)  -- Objekt, auf das gewartet wird wenn existiert
      WHERE  l.Inst_ID    = ?
      AND    l.SID        = ?
      AND    s.Serial#    = ?   
      ORDER BY 1                                                                          
      ", @instance, @sid, @serialno]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_session_details_locks" }');"}
    end
  end

  def show_session_details_temp
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serialno = params[:serialno]
    @saddr    = params[:saddr]

    @temps = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             SQL_ID, Tablespace, Contents, SegType,
             SUM(Extents) Extents,
             SUM(Blocks) Blocks
      FROM   gv$TempSeg_Usage u
      WHERE  Inst_ID = ?
      AND    Session_Addr = HexToRaw(?)
      GROUP BY SQL_ID, Tablespace, Contents, SegType
      ", @instance, @saddr]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_session_details_temp" }');"}
    end
  end

  def list_session_statistic
    @instance = prepare_param_instance
    @sid      = params[:sid]

    @stats = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             s.Statistic#    StatisticNo,
             s.Value,
             n.Class,
             n.Name
      FROM   gv$SesStat s
      JOIN   v$StatName n ON n.Statistic# = s.Statistic#
      WHERE  s.Inst_ID = ?
      AND    s.SID = ?
      AND    s.Value != 0
      ", @instance, @sid]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_session_statistic" }');"}
    end
  end



  # Ermitteln Object aus Parametern von v$session_wait
  def show_session_details_waits_object
    @object = object_nach_wait_parameter(params[:instance], params[:event],
            params[:p1], params[:p1raw], params[:p1text],
            params[:p2], params[:p2raw], params[:p2text],
            params[:p3], params[:p3raw], params[:p3text]
          )
    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j @object }');"}
    end
  end
    
  def show_explain_plan
    ActiveRecord::Base.connection.execute "EXPLAIN PLAN SET Statement_ID='Panorama' FOR " + params[:statement]
    @plans = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Operation, Options, Object_Name, Optimizer,
          Access_Predicates, Filter_Predicates,
          Other_Tag, Distribution
        FROM  Plan_Table p
        WHERE Statement_ID=?",
        "Panorama"
        ]
    ActiveRecord::Base.connection.execute "DELETE FROM Plan_Table WHERE STatement_ID='Panorama'"
    respond_to do |format|
      format.js {render :js => "$('#explain_plan_area').html('#{j render_to_string :partial=> "list_explain_plan" }');"}
    end
  end
  
  
  def segment_stat   # Anzeige Auswahl-Dialog für Statistiken
    @stats = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */
          DISTINCT Statistic_Name
        FROM  GV$Segment_Statistics
        WHERE Value != 0"
        
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/segment_stat" }');"}
    end
  end

  
  def show_segment_statistics
    def smaller(obj1, obj2)
      return true   if obj1.inst_id < obj2.inst_id
      return false  if obj1.inst_id > obj2.inst_id
      return true   if obj1.object_type < obj2.object_type
      return false  if obj1.object_type > obj2.object_type
      return true   if obj1.owner < obj2.owner
      return false  if obj1.owner > obj2.owner
      return true   if obj1.object_name < obj2.object_name
      return false  if obj1.object_name > obj2.object_name
      return true   if !obj1.subobject_name && obj2.subobject_name  # NULL < Wert
      return false  if !obj2.subobject_name  # NULL < Wert
      return true   if obj1.subobject_name < obj2.subobject_name
      return false 
    end
    
    def get_values  # ermitteln der Aktuellen Werte
      # Sortierung des Results muss mit Methode smaller korrelieren
      sql_select_all ["\
        SELECT /* NOA-Tools Ramm */                             
          Inst_ID, Owner, Object_Name, SubObject_Name,          
          Object_Type, Value                                    
        FROM  GV$Segment_Statistics                             
        WHERE Statistic_Name=?                                  
        AND   Value != 0                                        
        ORDER BY Inst_ID, Object_Type, Owner, Object_Name, SubObject_Name",
        params[:statistic_name][:statistic_name]
        ]
    end # get_values

    # Sicherstellen, dass SQL-Sortierung analog der Sortierung in Ruby erfolgt
    ActiveRecord::Base.connection.execute "ALTER SESSION SET NLS_SORT=BINARY"

    @header = params[:statistic_name][:statistic_name]

    @column_options =
       [
         {:caption=>"Inst",        :data=>"rec.inst_id",             :title=>"RAC-Instance"},
         {:caption=>"Type",        :data=>"rec.object_type",         :title=>"Object-Type"},
         {:caption=>"Owner",       :data=>"rec.owner",               :title=>"Object-Owner"},
         {:caption=>"Name",        :data=>"rec.object_name",         :title=>"Object-Name"},
         {:caption=>"Sub-Name",    :data=>"rec.subobject_name",      :title=>"Sub-Object-Name"},
         {:caption=>"Sample",      :data=>proc{|rec| formattedNumber(rec.sample)}, :title=>"Statistik-Wert innerhalb der Sample-Dauer",    :align=>"right"},
         {:caption=>"Total",       :data=>proc{|rec| formattedNumber(rec.total)},  :title=>"Statistik-Wert global sei Instance-Start",     :align=>"right"},
       ]

    data1 = get_values    # Snapshot vor SampleTime
    sampletime = params[:sample_length].to_i
    if sampletime == 0    # Kein Sample gewünscht
      data2 = data1       # selbes Result noch einmal verwenden
    else
      sleep sampletime     
      ActiveRecord::Base.connection.clear_query_cache # Result-Caching Ausschalten für wiederholten Zugriff
      data2 = get_values    # Snapshot nach SampleTime
    end
    @data = []            # Leeres Array für Result
    d1_akt_index = 0;     # Vorlesen
    d2_akt_index = 0;     # Vorlesen
    while d1_akt_index < data1.length && d2_akt_index < data2.length # not EOF
      d1 = data1[d1_akt_index];   # Vorlauf Gruppe
      d2 = data2[d2_akt_index];   # Vorlauf Gruppe
      # Verarbeitung
      if d1.inst_id==d2.inst_id && d1.object_type==d2.object_type && d1.owner==d2.owner && d1.object_name==d2.object_name && d1.subobject_name==d2.subobject_name
        if params[:only_sample_change]!='1' || d2.value != d1.value
          @data << {
            "inst_id" => d1.inst_id,
            "object_type" => d1.object_type,
            "owner" => d1.owner,
            "object_name" => d1.object_name,
            "subobject_name" => d1.subobject_name,
            "sample" => d2.value - d1.value,
            "total" => d2.value
          }
        end
      end
      # Nachlesen für den Fall distinct Sätze
      if smaller(d1,d2)
        d1_akt_index = d1_akt_index+1
      else  
        d2_akt_index = d2_akt_index+1
      end
    end

    @data.each do |d|
      d.extend SelectHashHelper   # Hash per Methode zugriffsfaehig machen
    end

    @data = @data.sort {|x,y| y.sample <=> x.sample }

    output = gen_slickgrid(@data, @column_options, {:caption=>@header, :width=>"auto"})

    respond_to do |format|
      format.js {render :js => "$('#segment_statistics_detail').html('#{j output}');"}
    end
  end


  def temp_usage
    @data = sql_select_all "\
        SELECT /* NOA-Tools Ramm */ t.INST_ID,
        s.SID,
        s.Serial# SerialNo,
        s.UserName,
        s.Status,
        s.OSUser,
        s.Process,
        s.Machine,
        s.Program,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        t.Tablespace,
        t.SegType,
        t.Extents,
        t.Blocks
        FROM GV$TempSeg_Usage t,
             gv$session s
        WHERE s.Inst_ID = t.Inst_ID
        AND   s.SAddr = t.Session_Addr"
    
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=>"dba/temp_usage" }');"}
    end
  end

  def show_session_waits
    @wait_sums = sql_select_all "\
      SELECT /*+ ORDERED USE_NL(s) Panorama Ramm */
             COUNT(*) Anzahl,
             w.Inst_ID,
             DECODE(w.State, 'WAITING', w.Event, 'ON CPU') Event,
             DECODE(w.State, 'WAITING', w.Wait_Class, NULL) Wait_Class,
             DECODE(w.State, 'WAITING', w.State, NULL) State,
             SUM(w.Wait_Time) Wait_Time,
             SUM(w.Seconds_In_wait) Sum_Seconds_In_Wait,
             MAX(w.Seconds_In_Wait) Max_Seconds_In_Wait,
             CASE WHEN COUNT(DISTINCT s.Module) = 1 THEN MIN(s.Module) ELSE
                  TO_CHAR(COUNT(DISTINCT s.Module)) END Modules
      FROM   gv$Session_Wait w
     JOIN    gv$Session s ON s.Inst_ID = w.Inst_ID AND s.SID = w.SID
     WHERE w.Wait_Class != 'Idle'
     GROUP BY w.Inst_ID, DECODE(w.State, 'WAITING', w.Event, 'ON CPU'),
              DECODE(w.State, 'WAITING', w.Wait_Class, NULL), DECODE(w.State, 'WAITING', w.State, NULL)
     ORDER BY COUNT(*) DESC, SUM(w.Seconds_In_wait) DESC"

    @blocking_waits = sql_select_all "\
      WITH Locks AS (
              SELECT /*+ LEADING(l) */ /* Panorama-Tool Ramm */
                     s.Inst_ID,
                     s.SID,
                     s.Serial# SerialNo,
                     s.SQL_ID,
                     s.SQL_Child_Number,
                     s.Status,
                     s.Event,
                     s.Client_Info,
                     s.Module,
                     s.Action,
                     s.UserName,
                     s.machine,
                     s.OSUser,
                     s.Process,
                     s.program,
                     bo.Owner               Blocking_Object_Schema,
                     bo.Object_Name         Blocking_Object_Name,
                     bo.Data_Object_ID,
                     s.Row_Wait_File#       Row_Wait_File_No,
                     s.Row_Wait_Block#      Row_Wait_Block_No,
                     s.Row_Wait_Row#        Row_Wait_Row_No,
                     s.Seconds_In_Wait,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_SerialNo,
                     bs.Status              Blocking_Status,
                     bs.Event               Blocking_Event,
                     bs.Client_Info         Blocking_Client_Info,
                     bs.Module              Blocking_Module,
                     bs.Action              Blocking_Action,
                     bs.UserName            Blocking_UserName,
                     bs.Machine             Blocking_Machine,
                     bs.OSUser              Blocking_OSUser,
                     bs.Process             Blocking_Process,
                     bs.Program             Blocking_Program
               FROM gv$session s
               JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
               -- Object der blockenden Session
               LEFT OUTER JOIN sys.DBA_Objects bo ON bo.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Objekt */ s.P2
                                                                    ELSE CASE WHEN s.Row_Wait_Obj# != -1 THEN /* Session kennt Objekt */   s.Row_Wait_Obj#
                                                                         ELSE NULL
                                                                         END
                                                                    END
               WHERE s.type = 'USER'
              ),
      HLocks AS (
              SELECT /*+ NO_MERGE */ RowNum Row_Num, Level HLevel, l.*,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serialno = blocking_serialNo
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.SerialNo = l.SerialNo
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num"

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @blocking_waits.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }
    respond_to do |format|
      format.js {render :js => "$('#content_for_layout').html('#{j render_to_string :partial=> "dba/show_session_waits" }');"}
    end
  end

  def list_waits_per_event
    @instance = params[:instance]
    @event    = params[:event]
    @waits = sql_select_all ["\
      SELECT /*+ ORDERED USE_NL(s) Panorama Ramm */
             w.Inst_ID, w.SID, s.Serial# SerialNo, w.Event, w.Wait_Class,
             w.P1Text, w.P1, w.P1Raw,
             w.P2Text, w.P2, w.P2Raw,
             w.P3Text, w.P3, w.P3Raw,
             w.Wait_Time, w.Seconds_In_wait, w.State,
             s.Client_Info, s.Module, s.Action,
             s.SQL_ID, s.Prev_SQL_ID, s.SQL_Child_Number, s.Prev_Child_Number
      FROM   gv$Session_Wait w
      JOIN   gv$Session s ON s.Inst_ID = w.Inst_ID AND s.SID = w.SID
      WHERE  w.Inst_ID = ? 
      AND    ((? = 'ON CPU' AND w.State != 'WAITING') OR w.Event   = ?) ",
      @instance, @event, @event]

    respond_to do |format|
      format.js {render :js => "$('##{params[:update_area]}').html('#{j render_to_string :partial=>"list_waits_per_event" }');"}
    end
  end



end # Class
