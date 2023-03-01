# encoding: utf-8
class DbaController < ApplicationController

  include DbaHelper

  def show_locks
    @dml_count = sql_select_first_row "
      SELECT COUNT(*) DML_Count, SUM(CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 THEN 1 ELSE 0 END) Blocking_DML_Count
      FROM   gv$Lock l
      JOIN   gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
      WHERE  s.type          = 'USER'
      AND    l.Type NOT IN ('AE', 'PS')
    "

    begin
      @ddl_count = sql_select_one "SELECT /* Panorama-Tool Ramm */ COUNT(*)
                                  FROM  dba_kgllock w,
                                        dba_kgllock h
                                  WHERE   (((h.kgllkmod != 0)     and (h.kgllkmod != 1)
                                  and     ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
                                  and     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
                                  and     ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
                                  and     w.kgllktype             = h.kgllktype
                                  and     w.kgllkhdl              = h.kgllkhdl
      "
    rescue Exception => e                                                       # Skip ORA-7445 during select
      @ddl_count = nil
      add_statusbar_message("Error skipped while counting the number of DDL-Locks:\n#{e.message}")
    end

    @blocking_session_count = sql_select_one "\
      SELECT /* Panorama-Tool Ramm */ COUNT(*)
      FROM gv$session s
      JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
      WHERE s.type = 'USER'"

    @pending_2pc_count = sql_select_one "SELECT COUNT(*) FROM DBA_2PC_Pending"

    render_partial
  end

  def list_dml_locks
    show_all_locks = params[:show_all_locks]
    
    @max_result_size = params[:max_result_size].to_i

    where_string =  ''
    where_values = []

    if params[:id1]
      where_string << " AND l.ID1 = ?"
      where_values << params[:id1].to_i
    end

    if params[:id2]
      where_string << " AND l.ID2 = ?"
      where_values << params[:id2].to_i
    end


    @dml_locks = sql_select_all(["\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock)
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (
              SELECT /*+ ORDERED */
                RowNum                                                      ,
                l.Inst_ID                                                   Instance_Number,
                s.SID,
                s.Serial#                                                   Serial_No,
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
                #{get_db_version < '11.1' ? "s.Seconds_In_Wait" : "DECODE(s.State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro)/1000000"} WaitingForTime,
                l.ctime                                                     Lock_Held_Seconds,
                SUBSTR(l.ID1||':'||l.ID2,1,12)                              ID1ID2,
                /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                TO_CHAR(l.Request)                                          Request,
                TO_CHAR(l.lmode)                                            LockMode,
                RowNum      /* fuer Ajax-Aktualisierung der Zeile */        Row_Num,
               bs.Inst_ID             Blocking_Instance_Number,
               bs.SID                 Blocking_SID,
               bs.Serial#             Blocking_Serial_No
              FROM    RawLock l
              JOIN    gv$session s              ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
              JOIN    GV$Process p              ON p.Inst_ID = s.Inst_ID AND p.Addr = s.pAddr
              LEFT OUTER JOIN gv$Session bs     ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
              LEFT OUTER JOIN DBA_Objects lo    ON lo.Object_ID = l.ID1  -- locked object
              LEFT OUTER JOIN gv$Transaction x  ON x.Inst_ID = s.Inst_ID AND x.Addr = s.TAddr
              -- Join über dem Wait bekanntes Object, alternativ über der session bekanntes Objekt auf das gewartet wird
              -- Bei Request = 3 enthaelt row_wait_obj# zuweilen das vorherige Objekt statt des aktuellen, in dem Falle ist auch die RowID Murks
              LEFT OUTER JOIN DBA_Objects o     ON o.Object_ID = DECODE(s.P2Text, 'object #', s.P2, DECODE(s.Row_Wait_Obj#, -1, NULL, s.Row_Wait_Obj#))  -- Objekt, auf das gewartet wird wenn existiert
              WHERE   s.type          = 'USER'
              #{where_string}
            )
      #{show_all_locks ? "" : " WHERE LockType NOT IN ('AE', 'PS') "  }  -- Type-Filter ausserhalb des Selects weil sonst auf Exadata/11g utopische Laufzeiten wegen Cartesian Join
      ORDER BY Inst_ID, SID, Locked_Object_Name
      "].concat(where_values))
    @result_size = @dml_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    @dml_locks.delete_at(@dml_locks.length-1) while @dml_locks.length > @max_result_size

    add_statusbar_message(t(:dba_list_dml_locks_cancelled, :default=>'Listing cancelled after %{max_result_size} rows, result has %{result_size} rows in total', :max_result_size=>@max_result_size, :result_size=>@result_size)) if @result_size > @max_result_size

    render_partial :list_dml_locks
  end # list_dml_locks

  def list_blocking_dml_locks

    # TODO: Use v$Session.Final_Blocking_Instance and Final_Blocking_Session instead of CONNECT BY. Check if result is comparable before!
    @locks = sql_select_all "\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock),
           Locks AS (
              SELECT /*+ LEADING(l) */ /* Panorama-Tool Ramm */
                     l.Inst_ID,
                     s.SID,
                     s.Serial# Serial_No,
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
                     s.Wait_Time_Micro/1000000 Seconds_Waiting,
                     DECODE(bs.State, 'WAITING', bs.Wait_Time_Micro/1000000) Blocking_Seconds_Waiting,
                     l.ID1,
                     l.ID2,
                     /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                     l.Request Request,
                     l.lmode   LockMode,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_Serial_No,
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
               FROM RawLock l
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
                     CONNECT_BY_ROOT Blocking_Serial_No        Root_Blocking_Serial_No
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serial_no = blocking_serial_no
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.Serial_No = l.Serial_No
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num"

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    render_partial :list_blocking_dml_locks
  end

  def list_pending_two_phase_commits
    @dist_locks = sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             Local_Tran_ID,
             Global_tran_ID,
             State, Mixed, Advice, Tran_Comment,
             Fail_Time, Force_Time, Retry_Time,
             OS_User, OS_Terminal, Host, DB_User,
             Commit# Commit_No
      FROM   DBA_2PC_Pending"

    render_partial
  end

  def list_2pc_neighbors
    @local_tran_id = prepare_param(:local_tran_id)

    @neighbors = sql_select_iterator ["SELECT * FROM DBA_2PC_Neighbors WHERE Local_Tran_ID = ?", @local_tran_id]
    render_partial
  end

  def hang_analyze
    respond_to do |format|
      format.html {render :html => "\
<div class=\"yellow-panel\">
-- Before fixing an blocking situation by \"SHUTDOWN ABORT\" or \"ALTER SYSTEM KILL SESSION\" you should record the current state for later investigation.
-- Therefore execute the following commands as sysdba e.g. by \"sqlplus / as sysdba\"

 oradebug setmypid
 oradebug unlimit
 oradebug hanganalyze 3
 oradebug dump ashdumpseconds 30
 oradebug dump systemstate 266
 oradebug tracefile_name

-- In case you cannot create a new session by \"sqlplus / as sysdba\" do \"sqlplus -prelim / as sysdba\" instead
-- and connect to an existing idle process instead of \"oradebug setmypid\"
oradebug setorapname diag

-- Thanks to Franck Pachot for his explanations:
-- https://blog.dbi-services.com/oracle-is-hanging-dont-forget-hanganalyze-and-systemstate/

</div>
      ".gsub(/\n/, '<br/>').html_safe }
    end
  end

  def convert_to_rowid
    @data_object_id = params[:data_object_id]

    @rowid = sql_select_one ["SELECT RowIDTOChar(DBMS_RowID.RowID_Create(1, ?, ?, ?, ?)) FROM DUAL",
                             params[:data_object_id].to_i,
                             params[:row_wait_file_no].to_i,
                             params[:row_wait_block_no].to_i,
                             params[:row_wait_row_no].to_i
                            ]

    render_partial :list_rowid_link
  end

  # Anzeige der ApplInfo auf Basis der Client_Info aus v$session
  def explain_info
    @info = params[:info]

    res = explain_application_info(@info)
    if res[:short_info]
      res_string = "#{res[:short_info]} : #{res[:long_info]}"
    else
      res_string = "No info available"
    end

    respond_to do |format|
      format.html {render :html => res_string }
    end
  end

  def list_ddl_locks

    #@max_result_size = params[:max_result_size].to_i

    @ddl_locks = sql_select_all("\
      SELECT /*+ ordered */ /* Panorama-Tool Ramm */
        hs.Inst_ID                                                  B_Inst_ID,
        hs.SID                                                      B_SID,
        hs.Serial#                                                  B_Serial_No,
        hs.Status                                                   B_Status,
        hp.spID                                                     B_PID,
        hs.UserName                                                 B_User,
        hs.Machine                                                  B_Machine,
        hs.OSUser                                                   B_OSUser,
        hs.Process                                                  B_Process,
        hs.Program                                                  B_Program,
        ws.Inst_ID                                                  W_Inst_ID,
        ws.SID                                                      W_SID,
        ws.Serial#                                                  W_Serial_No,
        wp.spID                                                     W_PID,
        ws.UserName                                                 W_User,
        ws.Machine                                                  W_Machine,
        ws.OSUser                                                   W_OSUser,
        ws.Process                                                  W_Process,
        ws.Program                                                  W_Program,
        w.kgllktype                                                 LockType,
        od.TO_Owner                                                 Object_Owner,
        od.TO_Name                                                  Object_Name,
        decode(h.kgllkmod,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_held,
        decode(w.kgllkreq,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_requested
      FROM  dba_kgllock w
      JOIN  dba_kgllock h                     ON h.kgllktype = w.kgllktype AND h.kgllkhdl = w.kgllkhdl
      JOIN  GV$session ws                     ON ws.saddr = w.kgllkuse
      JOIN  GV$session hs                     ON hs.saddr = h.kgllkuse
      JOIN  GV$Process wp                     ON wp.Addr = ws.pAddr AND wp.Inst_ID = ws.Inst_ID
      JOIN  GV$Process hp                     ON hp.Addr = hs.pAddr AND hp.Inst_ID = hs.Inst_ID
      LEFT OUTER JOIN (SELECT DISTINCT TO_Address, TO_Owner, TO_Name FROM v$Object_dependency) od  ON od.TO_ADDRESS = w.kgllkhdl /* v$Object_dependency may have multiple redundant entries */
      WHERE   (((h.kgllkmod != 0)     and (h.kgllkmod != 1)
      and     ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
      and     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
      and     ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
      ")

    #@result_size = @ddl_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    #@ddl_locks.delete_at(@ddl_locks.length-1) while @ddl_locks.length > @max_result_size

    render_partial :list_ddl_locks
  end # list_ddl_locks

  # Extrahieren des PKey und seines Wertes für RowID
  def show_rowid_details
    rowid     = params[:waitingforrowid]

    object_rec = sql_select_first_row ["\
                   SELECT Owner, Object_Name, SubObject_Name, Object_Type
                   FROM   DBA_Objects
                   WHERE  Data_Object_ID = ?
                   ",
                   params[:data_object_id]]

    unless object_rec
      show_popup_message "No object found for Data_Object_ID=#{params[:data_object_id]}"
      return
    end

    if object_rec.object_type.match("INDEX")
      table_name = sql_select_first_row(["\
                     SELECT Table_Name
                     FROM   DBA_Indexes
                     WHERE  Owner = ?
                     AND    Index_Name = ?",
                     object_rec.owner, object_rec.object_name]).table_name
    else
      table_name = object_rec.object_name
    end

    pstmt = sql_select_all ["\
             SELECT Column_Name                                              
             FROM   DBA_Ind_Columns
             WHERE  Index_Owner   = ?
             AND    Index_Name =                                             
                    (SELECT Index_Name                                       
                     FROM   DBA_Constraints
                     WHERE  Owner      = ?
                     AND    Table_Name = UPPER(?)
                     AND    Constraint_Type = 'P'                            
                    )", object_rec.owner, object_rec.owner, table_name]
    if pstmt.length == 0
      show_popup_message "No primary key found for object '#{object_rec.owner}.#{object_rec.object_name} / table #{table_name}"
      return
    end

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

    begin
      pkey_vals = sql_select_first_row ["SELECT #{pkey_cols} FROM #{object_rec.owner}.#{table_name} WHERE RowID=?", rowid]
    rescue Exception => e
      show_popup_message "Error accessing data for RowID='#{rowid}'\n\n#{e.message}"
      return
    end
    raise PopupMessageException.new("No data found for SQL:\n\n#{pkey_sql}\n\nParameter RowID = '#{rowid}'") if pkey_vals.length == 0

    result = "#{t(:table, :default=>'table')} #{table_name}, PKey (#{pkey_cols}) = "

    pstmt.each_index do |i|
      column_value = pkey_vals[pstmt[i].column_name.downcase]
      delimiter = ''
      delimiter = "'" if [String, DateTime, Date, Time].include? column_value.class
      result << "#{delimiter}#{column_value}#{delimiter}"
      result << ", " if i < pkey_vals.count-1
    end

    respond_to do |format|
      format.html {render :html => result }
    end
  end # show_lock_details

  def show_redologs
    @instance = prepare_param_instance

    @redologs = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
        Inst_ID,
        TO_CHAR(Group#) GroupNo,                                
        Bytes/(1024*1024) MByte,
        Status,                                                 
        First_Time,
        #{"(Next_Time - First_Time) * 86400 Log_Switch_Interval_Secs," if get_db_version >= '11.1'}
        Members, Archived
      FROM gV$LOG
      WHERE Inst_ID = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# getzeigt, dies verhindert die Dopplung
      #{"AND Inst_ID = #{@instance}" if @instance}
    ORDER BY First_Time DESC")

    render_partial
  end # show_redologs

  def list_redolog_members
    @instance = params[:instance]
    @group    = params[:group]

    @members = sql_select_iterator ["
      SELECT *
      FROM   gv$LogFile
      WHERE  Inst_ID = ?
      AND    Group#  = ?
    ", @instance, @group]

    render_partial
  end

  def list_redologs_log_history
    @instance = prepare_param_instance
    save_session_time_selection  # werte in session puffern
    @time_groupby = prepare_param(:time_groupby).to_sym

    wherestr = ""
    whereval = []

    if @instance
      wherestr << " AND l.Inst_ID = ?"
      whereval << @instance
    end

    if @time_groupby == :single
      @switches = sql_select_iterator ["\
        SELECT l.*
        FROM   (SELECT l.*, (LEAD(l.First_Time, 1) OVER (PARTITION BY Thread# ORDER BY l.Sequence#) - l.First_Time) * 86400 Current_Duration_Secs
                FROM   gv$Log_History l
                WHERE  Inst_ID = Thread#  /* All instances know about all logs from other instances named by thread#, assuming thread# is equal to inst_id for duplicate entries */
                #{wherestr}
               ) l
        WHERE  First_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND First_Time < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
        ORDER BY First_Time
      "].concat(whereval).concat([@time_selection_start, @time_selection_end])
    else
      case @time_groupby
      when :second    then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 86400 + TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))"
      when :second_10 then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 8640 + TRUNC(TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))/10)"
      when :minute    then group_by_value = "TRUNC(l.First_Time, 'MI')"
      when :minute_10 then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 8640 + TRUNC(TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))/600)"
      when :hour      then group_by_value = "TRUNC(l.First_Time, 'HH24')"
      when :day       then group_by_value = "TRUNC(l.First_Time)"
      when :week      then group_by_value = "TRUNC(l.First_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :time_groupby (#{@time_groupby})"
      end

      @switches = sql_select_iterator ["\
        SELECT l.*, LEAD(l.Min_First_Time, 1) OVER (ORDER BY l.Min_First_Time) Next_time
        FROM   (SELECT MIN(First_Time) Min_First_Time, COUNT(DISTINCT Inst_ID) Instances, COUNT(*) Log_Switches,
                       AVG(Next_Time-First_Time) * 86400    Avg_Current_Duration_Secs,
                       MIN(Next_Time-First_Time) * 86400    Min_Current_Duration_Secs,
                       MAX(Next_Time-First_Time) * 86400    Max_Current_Duration_Secs,
                       SUM(Next_Change# - First_Change#)    SCN_Increments
                FROM   (SELECT l.*, LEAD(l.First_Time, 1) OVER (PARTITION BY Thread# ORDER BY l.Sequence#) Next_time
                        FROM   gv$Log_History l
                        WHERE  Inst_ID = Thread#  /* All instances know about all logs from other instances named by thread#, assuming thread# is equal to inst_id for duplicate entries */
                        #{wherestr}
                       ) l
                WHERE  First_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND First_Time < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                GROUP BY #{group_by_value}
               ) l
        ORDER BY 1
      "].concat(whereval).concat([@time_selection_start, @time_selection_end])
    end

    render_partial
  end

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

    @redologs = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ x.*,
             x.LogSwitches * x.Members * x.Avg_Size_MB LogWrites_MB,
             CASE WHEN x.Snapshot_Secs > 0 AND x.LogSwitches IS NOT NULL AND x.LogSwitches > 0 THEN x.Snapshot_Secs / x.LogSwitches END Avg_Secs_Between_LogSwitches
      FROM   (SELECT ss.Begin_Interval_Time, ss.End_Interval_Time, l.*,
                     (CAST(ss.End_Interval_Time AS DATE)-CAST(ss.Begin_interval_Time AS DATE))*86400 Snapshot_Secs,
                     l.MaxSequenceNo - LAG(l.MaxSequenceNo, 1, l.MaxSequenceNo) OVER (PARTITION BY l.Instance_Number ORDER BY ss.Begin_Interval_Time) LogSwitches
              FROM   (
                      SELECT DBID, Snap_ID, Instance_Number, COUNT(*) Log_Number,
                             SUM(CASE WHEN Archived='NO' THEN 1 ELSE 0 END)     Not_Archived,
                             SUM(CASE WHEN Status='CURRENT' THEN 1 ELSE 0 END)  Current_No,
                             SUM(CASE WHEN Status='ACTIVE' THEN 1 ELSE 0 END)   Active_no,
                             Avg(Members)                                       Members,
                             AVG(Bytes)/ (1024*1024)                            Avg_Size_MB,
                             MAX(Sequence#)                                     MaxSequenceNo
                      FROM   DBA_Hist_Log
                      WHERE  DBID = ?
                      AND Instance_Number = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# gezeigt, dies verhindert die Dopplung
                      GROUP BY DBID, Snap_ID, Instance_Number
                     ) l
              JOIN   DBA_Hist_Snapshot ss ON ss.DBID=l.DBID AND ss.Snap_ID=l.Snap_ID AND ss.Instance_Number=l.Instance_Number
              WHERE  ss.Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_start)}')
              AND    ss.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_end)}') #{wherestr}
            ) x
      ORDER BY x.Begin_Interval_Time, x.Instance_Number
      ", @dbid, @time_selection_start, @time_selection_end].concat whereval

    render_partial
  end

  def oracle_parameter
    @instance = prepare_param_instance
    @option = prepare_param(:option)&.to_sym

    # Limited amount of values to show if filtering option is given
    option_names = {
      auditing: ["audit_sys_operations", "unified_audit_sga_queue_size", "audit_file_dest", "audit_syslog_level", "audit_trail"],
      memory:   ['memory_target', 'memory_max_target', 'pga_aggregate_limit', 'pga_aggregate_target', 'sga_max_size', 'sga_target']
    }

    raise "Unsupported option #{@option}" if !@option.nil? && !option_names.has_key?(@option)

    @caption = "#{t(:dba_oracle_parameter_caption, :default=>'Init-parameter of database')}#{" relevant for #{@option}" if @option}"

    @reduced_columns = params[:reduced_columns]

    where_string = ''
    where_values = []

    if @option
      where_string << " AND Name IN ("
      option_names[@option].each_index do |i|
        where_string << "?"
        where_string << "," if i < option_names[@option].count-1
        where_values << option_names[@option][i]
      end
      where_string << ")"
    end

    if @instance
      where_string << " AND Instance = ?"
      where_values << @instance
    end

    @hint = nil

    record_modifier = proc{|rec|
      rec.value = rec.value + " (Caution!!! This is local session setting of Panorama's DB-Session! Database default may differ! Use sqlplus with SELECT * FROM gv$Parameter WHERE name='cursor_sharing'; to read real defaults."  if rec.name == 'cursor_sharing'
      rec.value = rec.value + " (Caution!!! This is local session setting of Panoramas DB-Session! Database default may differ! Use sqlplus with SELECT * FROM gv$Parameter WHERE name='nls_length_semantics'; to read real defaults.)"  if rec.name == 'nls_length_semantics'
    }

    begin
      @parameters = sql_select_all(["\
        SELECT /* Panorama-Tool Ramm */ *
        FROM   (SELECT NVL(v.Instance,      i.Instance)      Instance,
                       NVL(v.ID,            i.ID)            ID,
                       NVL(v.ParamType,     i.ParamType)     ParamType,
                       NVL(v.Name,          i.Name)          Name,
                       NVL(v.Description,   i.Description)   Description,
                       NVL(v.Value,         i.Value)         Value,
                       NVL(v.Display_Value, i.Display_Value) Display_Value,
                       NVL(v.IsDefault,     i.IsDefault)     IsDefault,
                       v.ISSES_MODIFIABLE, v.IsSys_Modifiable, v.IsInstance_Modifiable, v.IsModified, v.IsAdjusted, v.IsDeprecated, v.Update_Comment#{", v.IsBasic" if get_db_version >= '11.1'}#{", v.Con_ID" if get_db_version >= '12.1'}
                FROM   (SELECT /*+ NO_MERGE */
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
                       ) i
                FULL OUTER JOIN (
                                 SELECT /*+ NO_MERGE */
                                        Inst_ID                Instance,
                                        Num                    ID,
                                        Type                   ParamType,
                                        Name,
                                        Description,
                                        Value,
                                        Display_Value,
                                        IsDefault,
                                        ISSES_MODIFIABLE, IsSys_Modifiable, IsInstance_Modifiable, IsModified, IsAdjusted, IsDeprecated, Update_Comment#{", IsBasic" if get_db_version >= '11.1'}#{", Con_ID" if get_db_version >= '12.1'}
                                 FROM  gv$Parameter
                                ) v ON v.Instance = i.Instance AND v.ID = i.ID+1
               )
        WHERE 1=1 #{where_string}
        ORDER BY Name, Instance"].concat(where_values),
        record_modifier
      )

    rescue Exception
      if @option.nil?
        @hint = "Access rights on tables X$KSPPI and X$KSPPSV are possibly missing!</br>
  Therefore only documented parameters from GV$Parameter are shown.</br></br>

  Possible solution to show underscore parameters also: Execute the following as user 'SYS':</br>
  &nbsp;&nbsp;  create view X_$KSPPI as select * from X$KSPPI;</br>
  &nbsp;&nbsp;  grant select on X_$KSPPI to public;</br>
  &nbsp;&nbsp;  create public synonym X$KSPPI for sys.X_$KSPPI;</br></br>

  &nbsp;&nbsp;  create view X_$KSPPSV as select * from X$KSPPSV;</br>
  &nbsp;&nbsp;  grant select on X_$KSPPSV to public;</br>
  &nbsp;&nbsp;  create public synonym X$KSPPSV for sys.X_$KSPPSV;
  ".html_safe

      end
      @parameters = sql_select_all(["\
        SELECT /* Panorama-Tool Ramm */ *
        FROM   (SELECT Inst_ID                Instance,
                       Num                    ID,
                       Type                   ParamType,
                       Name,
                       Description,
                       Value,
                       Display_Value,
                       IsDefault,
                       ISSES_MODIFIABLE, IsSys_Modifiable, IsInstance_Modifiable, IsModified, IsAdjusted, IsDeprecated, Update_Comment#{", IsBasic" if get_db_version >= '11.1'}#{", Con_ID" if get_db_version >= '12.1'}
                 FROM  gv$Parameter
                )
        WHERE 1=1 #{where_string}
        ORDER BY Name, Instance"].concat(where_values),
        record_modifier
      )
    ensure
      if @option == :auditing
        audit_sys_operations  = @parameters.select{|p| p.name.downcase == 'audit_sys_operations'  && p.value.upcase == 'TRUE'}.length > 0
        audit_trail_in_db     = @parameters.select{|p| p.name.downcase == 'audit_trail'           && p.value.upcase['DB']}.length > 0
        if audit_sys_operations && audit_trail_in_db
          @hint = "<span style=\"color: red;\">Caution: Remember that SYS actions are not recorded in DB even if 'audit_trail=DB'. They are written to OS system audit file (journalctl --system)</span>".html_safe
        end
      end
      render_partial
    end

  end # oracle_parameter

  # Latch-Waits wegen cache buffers chains
  def latch_cache_buffers_chains
@waits = sql_select_all("\
      SELECT /*+ FIRST_ROWS */ /* Panorama-Tool Ramm */
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

    render_partial
  rescue Exception => ex
    # render as html because format=>:html was requested, otherwhise test will fail
    alert_exception(ex, x_dollar_bh_solution_text, :html)
  end

  # Waits wegen db_file_sequential_read
  def wait_db_file_sequential_read
    @waits = sql_select_iterator "\
      SELECT /* Panorama-Tool Ramm */
        w.SID,                                                    
        w.Seq# Serial_No,
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

    render_partial
  end
  
  def list_sessions
    @instance         = prepare_param_instance
    @service_name     = prepare_param(:service_name)
    @pdb_name         = prepare_param(:pdb_name)
    @show_only_user   = prepare_param(:showOnlyUser)    == '1'
    @show_pq_server   = prepare_param(:showPQServer)    == '1'
    @only_avtive      = prepare_param(:onlyActive)      == '1'
    @show_only_dblink = prepare_param(:showOnlyDbLink)  == '1'
    @show_timer       = prepare_param(:showTimer)       == '1'
    @object_owner     = prepare_param(:object_owner)
    @object_name      = prepare_param(:object_name)
    @object_type      = prepare_param(:object_type)
    @filter           = prepare_param(:filter)

    where_string = ""
    where_values = []

    if @instance
      where_string << " AND s.Inst_ID = ?"
      where_values << @instance
    end

    if @service_name
      where_string << " AND s.Service_Name = ?"
      where_values << @service_name
    end

    if @pdb_name
      where_string << "s.Con_ID = (SELECT MIN(Con_ID) FROM gv$Containers WHERE Name = ?)"
      where_values << @pdb_name
    end


    if @show_only_user
      where_string << " AND s.type = 'USER'"
    end
    unless @show_pq_server
      where_string << ' AND pqc.QCInst_ID IS NULL'   # Nur die QCInst_ID is nicht belegt in gv$PX_Session. Die OCSID ist auch für den Query-Koordinator belegt, der ja kein PQ ist
    end
    if @only_avtive
      where_string << " AND s.Status='ACTIVE'"
    end
    if @show_only_dblink
      where_string << " AND UPPER(s.program) like 'ORACLE@%' AND UPPER(s.Program) NOT LIKE 'ORACLE@'||(SELECT UPPER(i.Host_Name) FROM gv$Instance i WHERE i.Inst_ID=s.Inst_ID)||'%' "
    end
    if @only_avtive && !@show_timer
      where_string << " AND w.Event != 'PL/SQL lock timer'"
    end
    if @object_owner && @object_name
      where_string << " AND (s.Inst_ID, s.SID) IN (SELECT /*+ NO_MERGE */ Inst_ID, SID FROM GV$Access WHERE Owner = ? AND Object = ?"
      where_string << " AND Type = ?" if @object_type
      where_string << ")"
      where_values << @object_owner
      where_values << @object_name
      where_values << @object_type if @object_type
    end
    if @filter
      where_string << " AND ("
      where_string << "    TO_CHAR(s.SID)       LIKE '%'||?||'%'";   where_values << @filter
      where_string << " OR TO_CHAR(s.Process)   LIKE '%'||?||'%'";   where_values << @filter
      where_string << " OR TO_CHAR(p.spid)      LIKE '%'||?||'%'";   where_values << @filter
      where_string << " OR s.UserName           LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.OSUser)      LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Machine)     LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.SQL_ID)      LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Client_Info) LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Client_Identifier) LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Module)      LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Action)      LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << " OR UPPER(s.Program)     LIKE '%'||UPPER(?)||'%'";   where_values << @filter
      where_string << ")"
    end

    @sessions = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
        s.SID,
        s.Serial# Serial_No,
        s.Status,
        s.SQL_ID,
        s.SQL_Child_Number,
        s.Inst_ID,
        #{"s.Con_ID, con.Name Container_Name, " if get_current_database[:cdb]}
        s.UserName,                 
        s.Client_Info,
        s.Module, s.Action,
        s.Client_Identifier,
        p.spID,
        p.PID,
        s.machine,                                                                                                                        
        s.OSUser,                                                                                                                         
        s.Process,                                                                                                                        
        s.program,
        s.Service_Name,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        s.Logon_Time,
        s.Blocking_Session_Status, s.Blocking_Instance, s.Blocking_Session,
        #{"s.Final_Blocking_Session_Status, s.Final_Blocking_Instance, s.Final_Blocking_Session," if get_db_version >= '12.1' }
        sci.Network_Encryption, sci.Network_Checksumming,
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
        pqc.QCInst_ID, pqc.QCSID, pqc.QCSerial# QCSerial_No,
        p.PGA_Used_Mem     + NVL(pq_mem.PQ_PGA_Used_Mem,0)     PGA_Used_Mem,
        p.PGA_Alloc_Mem    + NVL(pq_mem.PQ_PGA_Alloc_Mem,0)    PGA_Alloc_Mem,
        p.PGA_Freeable_Mem + NVL(pq_mem.PQ_PGA_Freeable_Mem,0) PGA_Freeable_Mem,
        p.PGA_Max_Mem      + NVL(pq_mem.PQ_PGA_Max_Mem,0)      PGA_Max_Mem,
        Open_Cursor, Open_Cursor_SQL,
        wa.Operation_Type, wa.Policy, wa.Active_Time_Secs, wa.Work_Area_Size_MB,
        wa.Expected_Size_MB, wa.Actual_Mem_Used_MB, wa.Max_Mem_Used_MB, wa.Number_Passes,
        wa.WA_TempSeg_Size_MB,
        CASE WHEN w.State = 'WAITING' THEN w.Event ELSE 'ON CPU' END Wait_Event,
        w.Wait_Class,
        RawToHex(tx.XID) XID,
        #{get_db_version < '11.1' ? "w.Seconds_In_Wait" : "DECODE(w.State, 'WAITING', w.Wait_Time_Micro, w.Time_Since_Last_Wait_Micro)/1000000"} Seconds_Waiting
      FROM    GV$session s
      LEFT OUTER JOIN (SELECT Inst_ID, SID, count(*) Open_Cursor, count(distinct sql_id) Open_Cursor_SQL
                       FROM   gv$Open_Cursor
                       GROUP BY Inst_ID, SID
                      ) oc ON oc.Inst_ID = s.Inst_ID AND oc.SID = s.SID
      LEFT OUTER JOIN ( SELECT px.QCInst_ID, px.QCSID, px.QCSerial#, Count(*) Anzahl FROM GV$PX_Session px
                       GROUP BY px.QCInst_ID, px.QCSID, px.QCSerial#
                      ) px ON  px.QCInst_ID = s.Inst_ID
                           AND px.QCSID     = s.SID
                           AND px.QCSerial# = s.Serial#
      LEFT OUTER JOIN GV$PX_Session pqc ON pqc.Inst_ID = s.Inst_ID AND pqc.SID=s.SID --AND pqc.Serial#=s.Serial#    -- PQ Coordinator, Serial_No stimmt in Oracle 12c nicht mehr überein zwischen v$Session und v$px_session
      LEFT OUTER JOIN    GV$sess_io i ON i.Inst_ID = s.Inst_ID AND i.SID = s.SID
      LEFT OUTER JOIN    GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
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
             (SELECT Inst_ID, Session_Addr, SUM(Extents) Temp_Extents, SUM(Blocks) Temp_Blocks, SUM(Blocks)*#{PanoramaConnection.db_blocksize}/(1024*1024) Temp_MB
              FROM   gv$Sort_Usage
              GROUP BY Inst_ID, Session_Addr
             ) temp ON temp.Inst_ID = s.Inst_ID AND temp.Session_Addr = s.sAddr
      #{"LEFT OUTER JOIN gv$Containers con ON con.Inst_ID=s.Inst_ID AND con.Con_ID=s.Con_ID" if get_current_database[:cdb]}
      LEFT OUTER JOIN gv$Session_Wait w ON w.Inst_ID = s.Inst_ID AND w.SID = s.SID
      LEFT OUTER JOIN gv$Transaction tx ON tx.Inst_ID = s.Inst_ID AND tx.Addr = s.TAddr
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Inst_ID, SID, Serial#,
                              DECODE(SUM(CASE WHEN Network_Service_Banner LIKE '%Encryption service adapter%' THEN 1 ELSE 0 END), 0, 'NO', 'YES') Network_Encryption,
                              DECODE(SUM(CASE WHEN Network_Service_Banner LIKE '%Crypto-checksumming service adapter%' THEN 1 ELSE 0 END), 0, 'NO', 'YES') Network_Checksumming
                       FROM   gV$SESSION_CONNECT_INFO
                       GROUP BY Inst_ID, SID, Serial#
                      )sci ON sci.Inst_ID = s.Inst_ID AND sci.SID = s.SID AND sci.Serial# = s.Serial#
      WHERE 1=1 #{where_string}
      ORDER BY 1 ASC"].concat(where_values)

    render_partial :list_sessions
  end
  
  def show_session_detail
    @dbid        = prepare_param_dbid
    @instance    = prepare_param_instance
    @sid         = params[:sid].to_i
    @serial_no    = params[:serial_no].to_i
    @update_area = params[:update_area]

    @dbsessions =  sql_select_all ["\
           SELECT s.SQL_ID, s.Prev_SQL_ID, RawToHex(s.SAddr) SAddr, #{"s.Con_ID, con.Name Container_Name, " if get_current_database[:cdb]}
                  s.SQL_Child_Number, s.Prev_Child_Number,
                  CASE WHEN s.State = 'WAITING' THEN s.Event ELSE 'ON CPU' END Wait_Event,
                  s.Status, s.Client_Info, s.Module, s.Action, s.AudSID,
                  s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                  SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                  s.Logon_Time,
                  sci.Network_Encryption, sci.Network_Checksumming,
                  p.spID, p.PID,
                  RawToHex(tx.XID) Tx_ID,
                  tx.Start_Time,
                  c.AUTHENTICATION_TYPE,
                  c.Client_CharSet, c.Client_Connection, c.Client_OCI_Library, c.Client_Version, c.Client_Driver,
                  s.SQL_Exec_Start, s.SQL_Exec_ID, s.Prev_Exec_Start, s.Prev_Exec_ID,
                  s.Blocking_Session_Status, s.Blocking_Instance, s.Blocking_Session, b.Serial# Blocking_Serial_No,
                  s.Final_Blocking_Session_Status, s.Final_Blocking_Instance, s.Final_Blocking_Session, fb.Serial# Final_Blocking_Serial_No
           FROM   GV$Session s
           LEFT OUTER JOIN GV$process p  ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID /* gv$Process sometimes not visible for active sessions in autonomous DB */
           LEFT OUTER JOIN GV$Session b  ON b.Inst_ID = s.Blocking_Instance AND b.SID = s.Blocking_Session
           LEFT OUTER JOIN GV$Session fb ON fb.Inst_ID = s.Final_Blocking_Instance AND fb.SID = s.Final_Blocking_Session
           LEFT OUTER JOIN (SELECT Inst_ID, SID#{', Serial#' if get_db_version >= '11.2'}, AUTHENTICATION_TYPE
                                   #{", Client_CharSet, Client_Connection, Client_OCI_Library, Client_Version, Client_Driver" if get_db_version >= "11.2" }
                            FROM   GV$Session_Connect_Info
                            WHERE  Inst_ID=? AND SID=?
                            #{' AND Serial#=?' if get_db_version >= '11.2' }
                            AND    RowNum < 2         /* Verdichtung da fuer jede Zeile des Network_Banners ein Record in GV$Session_Connect_Info existiert */
                           ) c ON c.Inst_ID = s.Inst_ID AND c.SID = s.SID #{'AND c.Serial# = s.Serial#'  if get_db_version >= '11.2' }
           LEFT OUTER JOIN gv$Transaction tx ON tx.Inst_ID = s.Inst_ID AND tx.Addr = s.TAddr
           CROSS JOIN (SELECT /*+ NO_MERGE */
                                   DECODE(SUM(CASE WHEN Network_Service_Banner LIKE '%Encryption service adapter%' THEN 1 ELSE 0 END), 0, 'NO', 'YES') Network_Encryption,
                                   DECODE(SUM(CASE WHEN Network_Service_Banner LIKE '%Crypto-checksumming service adapter%' THEN 1 ELSE 0 END), 0, 'NO', 'YES') Network_Checksumming
                            FROM   gV$SESSION_CONNECT_INFO
                            WHERE  Inst_ID=? AND SID=? AND Serial#=?
                           )sci
           #{"LEFT OUTER JOIN gv$Containers con ON con.Inst_ID=s.Inst_ID AND con.Con_ID=s.Con_ID" if get_current_database[:cdb]}
           WHERE  s.Inst_ID=? AND s.SID=? AND s.Serial#=?",
           @instance, @sid].concat( get_db_version >= "11.2" ? [@serial_no] : [] ).concat([@instance, @sid, @serial_no, @instance, @sid, @serial_no])

    if @dbsessions.length > 0   # Session lebt noch
      @dbsession = @dbsessions[0]
      current_sql  = get_sga_sql_statement(@instance, @dbsession.sql_id)       if @dbsession.sql_id
      previous_sql = get_sga_sql_statement(@instance, @dbsession.prev_sql_id)  if @dbsession.prev_sql_id

      @sql_data = [
          {:caption           => "Aktuelles SQL-Statement",
           :sql_id            => @dbsession.sql_id,
           :sql_child_number  => @dbsession.sql_child_number,
           :sql_text          => (current_sql.html_safe if current_sql)
          },
          {:caption           => "Vorheriges SQL-Statement",
           :sql_id            => @dbsession.prev_sql_id,
           :sql_child_number  => @dbsession.prev_child_number,
           :sql_text          => (previous_sql.html_safe if previous_sql)
          }
      ]

      if get_db_version >= '11.1'
        @sql_data[0][:sql_exec_start] = @dbsession.sql_exec_start
        @sql_data[0][:sql_exec_id]    = @dbsession.sql_exec_id
        @sql_data[1][:sql_exec_start] = @dbsession.prev_exec_start
        @sql_data[1][:sql_exec_id]    = @dbsession.prev_exec_id
      end

      @pq_coordinator = sql_select_all ["SELECT s.Inst_ID, s.SID, s.Serial# Serial_No,
                                              s.SQL_ID, s.SQL_Child_Number, s.Status, s.Client_Info, s.Module, s.Action,
                                              s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                                              SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                                              s.Logon_Time, p.spID, p.PID
                                       FROM   gv$PX_Session ps
                                       JOIN   gv$Session s ON s.Inst_ID = ps.QCInst_ID AND s.SID = ps.QCSID AND s.Serial# = ps.QCSerial#
                                       LEFT OUTER JOIN GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID /* gv$Process sometimes not visible for active sessions in autonomous DB */
                                       WHERE  ps.Inst_ID = ?
                                       AND    ps.SID     = ?
                                       AND    ps.Serial# = ?
                                      ", @instance, @sid, @serial_no]

      @open_cursor_counts = sql_select_first_row ["\
                         SELECT /*+ ORDERED USE_HASH(s) */
                                COUNT(*) Total,
                                SUM(CASE WHEN oc.SAddr=se.SAddr THEN 1 ELSE 0 END) Own_SAddr
                         FROM   GV$Session se
                         JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID AND oc.SID     = se.SID
                         WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
                         ", @instance, @sid, @serial_no]

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
            ", @instance, @sid, @serial_no, @instance, @sid, @serial_no]

      @workareas = sql_select_all ["\
        SELECT wa.*
        FROM   gv$SQL_Workarea_Active wa
        WHERE  Inst_ID=? AND SID=?
        UNION ALL
        SELECT wa.*
        FROM   gv$SQL_Workarea_Active wa
        WHERE  QCInst_ID = ? AND QCSID = ? AND (Inst_ID!= ? OR SID!= ?)
      ", @instance, @sid, @instance, @sid, @instance, @sid]

      render_partial :list_session_details
    else
      show_popup_message "Session #{@sid}/#{@serial_no} does not exist anymore at instance #{@instance}!"
    end
  end

  def render_session_detail_tracefile_button
    @instance     = prepare_param_instance
    @pid          = prepare_param :pid
    @update_area  = prepare_param :update_area
    result = sql_select_first_row ["SELECT f.Inst_ID, f.Adr_Home, f.Trace_FileName, f.Con_ID
                                    FROM   gv$Process p
                                    JOIN   gv$Diag_Trace_File f ON f.Inst_ID = p.Inst_ID AND p.tracefile LIKE '%'||f.trace_filename
                                    WHERE  p.Inst_ID = ?
                                    AND    p.PID = ?", @instance, @pid]
    if result
      render_button("Show trace file", {
          action:           :list_trace_file_content,
          instance:         @instance,
          adr_home:         result.adr_home,
          trace_filename:   result.trace_filename,
          con_id:           result.con_id,
          update_area:      @update_area
      }, title: 'Show content of existing trace file for this session'
      )
    else
      render html: ''
    end
  end

  def render_session_detail_sql_monitor
    @dbid        = prepare_param_dbid
    @instance     = prepare_param_instance
    @sid          = prepare_param :sid
    @serial_no     = prepare_param :serial_no
    save_session_time_selection
    @update_area  = prepare_param :update_area

    @sql_monitor_reports_count = get_sql_monitor_count(@dbid, @instance, nil, @time_selection_start, @time_selection_end, @sid, @serial_no)

    render_button("SQL-Monitor (#{@sql_monitor_reports_count})", {
        controller:           :dba_history,
        action:               :list_sql_monitor_reports,
        instance:             @instance,
        sid:                  @sid,
        serial_no:             @serial_no,
        time_selection_start: @time_selection_start,
        time_selection_end:   @time_selection_end,
        update_area:      @update_area
    }, title: strings(:sql_monitor_list_title)
    )
  end

  def list_open_cursor_per_session
    @instance =  prepare_param_instance
    @sid     =  params[:sid].to_i
    @serial_no = params[:serial_no].to_i

    @opencursors = sql_select_iterator ["
      SELECT /*+ ORDERED USE_HASH(s wa) */
             oc.*,
             -- oc.SQL_ID oc_SQL_ID, oc.SQL_Text,
             wa.*,
             CASE WHEN se.SAddr = oc.SAddr THEN 'YES' ELSE 'NO' END Own_SAddr,
             sse.SID SAddr_SID, sse.Serial# SAddr_Serial_No
             #{", s.Child_Number" if get_db_version >= '12.1'}
      FROM   GV$Session se
      JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID
                              AND oc.SID     = se.SID
      LEFT OUTER JOIN (SELECT Inst_ID, Address, Hash_Value,
                               SUM(Estimated_Optimal_Size)/(1024)  Estimated_Optimal_Size_KB,
                               SUM(Estimated_OnePass_Size)/(1024)  Estimated_OnePass_Size_KB,
                               SUM(Last_Memory_used)/(1024)        Last_Memory_Used_KB,
                               SUM(Active_Time)/1000               Active_Time_ms,
                               SUM(Max_TempSeg_Size)/(1024)        Max_TempSeg_Size_KB,
                               SUM(Last_TempSeg_Size)/(1024)       Last_TempSeg_Size_KB
                       FROM   gv$SQL_Workarea
                       GROUP BY Inst_ID, Address, Hash_Value
                      ) wa ON wa.Inst_ID    = oc.Inst_ID
                          AND wa.Address    = oc.Address
                          AND wa.Hash_Value = oc.Hash_Value
      LEFT OUTER JOIN gv$Session sse ON sse.Inst_ID = oc.Inst_ID AND sse.SAddr = oc.SAddr
      #{"LEFT OUTER JOIN gv$SQL s ON s.Inst_ID = oc.Inst_ID AND s.Child_Address = oc.Child_Address" if get_db_version >= '12.1'}
      WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
      ", @instance, @sid, @serial_no]

    render_partial :list_open_cursor_per_session
  end

  def show_session_details_waits
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serial_no = params[:serial_no]

    @waits =  sql_select_all ["\
      SELECT s.Inst_ID, s.SID, s.Event,
             s.P1Text, s.P1, s.P1Raw,
             s.P2Text, s.P2, s.P2Raw,
             s.P3Text, s.P3, s.P3Raw,
             s.wait_Class,
             #{get_db_version >= '11.2' ? 's.Wait_Time_Micro/1000' : 's.Seconds_in_Wait*1000'} Wait_Time_ms,
             s.State,
             s.Blocking_Session_Status, s.Blocking_Instance, s.Blocking_Session, b.Serial# Blocking_Serial_No,
             s.Final_Blocking_Session_Status, s.Final_Blocking_Instance, s.Final_Blocking_Session, fb.Serial# Final_Blocking_Serial_No
      FROM   GV$Session s
      LEFT OUTER JOIN GV$Session b  ON b.Inst_ID = s.Blocking_Instance AND b.SID = s.Blocking_Session
      LEFT OUTER JOIN GV$Session fb ON fb.Inst_ID = s.Final_Blocking_Instance AND fb.SID = s.Final_Blocking_Session
      WHERE  s.Inst_ID = ?
      AND    s.SID     = ?
      ", @instance, @sid]

    @pq_waits =  sql_select_all ["\
      SELECT s.Program,
             px.Inst_ID,
             px.SID,
             px.Serial# Serial_No,
             px.req_degree,
             px.degree,
             s.Event,
             s.P1Text, s.P1, s.P1Raw,
             s.P2Text, s.P2, s.P2Raw,
             s.P3Text, s.P3, s.P3Raw,
             s.wait_Class,
             #{get_db_version >= '11.2' ? 's.Wait_Time_Micro/1000' : 's.Seconds_in_Wait*1000'} Wait_Time_ms,
             s.State,
             s.Blocking_Session_Status, s.Blocking_Instance, s.Blocking_Session, b.Serial# Blocking_Serial_No,
             s.Final_Blocking_Session_Status, s.Final_Blocking_Instance, s.Final_Blocking_Session, fb.Serial# Final_Blocking_Serial_No
      FROM   GV$PX_Session px
      JOIN   GV$Session s ON s.Inst_ID = px.Inst_ID AND s.SID = px.SID AND s.Serial# = px.serial#
      LEFT OUTER JOIN GV$Session b  ON b.Inst_ID = s.Blocking_Instance AND b.SID = s.Blocking_Session
      LEFT OUTER JOIN GV$Session fb ON fb.Inst_ID = s.Final_Blocking_Instance AND fb.SID = s.Final_Blocking_Session
      WHERE  px.QCInst_ID = ?
      AND    px.QCSID     = ?
      ", @instance, @sid]

    render_partial :list_session_details_waits
  end

  def show_session_details_locks
    @instance = prepare_param_instance
    @sid      = params[:sid]&.to_i
    @serial_no = params[:serial_no]&.to_i

    @locks =  sql_select_all ["\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock)
      SELECT /*+ ORDERED */ /* Panorama-Tool Ramm */
             RowNum,
             CASE
               WHEN l.Type='TM' THEN         /* Locked Object for TM */
                 (SELECT LOWER(o.Owner)||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
               WHEN l.Type='TX' THEN         /* Used Rollback Segment for TX */
                 (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV\$Transaction x WHERE x.Addr=s.TAddr)
             END                                                         Object,
             l.Type                                                      LockType,
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN o.Owner END                  Blocking_Owner,        /* Waiting for Lock */
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN o.Object_Name END            Blocking_Object_Name,  /* Waiting for Lock */
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 AND s.Row_Wait_Obj# != -1  THEN
               RowIDTOChar(DBMS_RowID.RowID_Create(1, o.Data_Object_ID, s.Row_Wait_File#, s.Row_Wait_Block#, s.Row_Wait_Row#))
             END                                                         WaitingForRowID,
             o.Data_Object_ID                                            WaitingForData_Object_ID,
             l.ctime Seconds_In_Lock,
             l.ID1, l.ID2,
             /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
             TO_CHAR(l.Request)                                          Request,
             TO_CHAR(l.lmode)                                            LockMode,
             bs.Inst_ID                                                  Blocking_Instance_Number,
             bs.SID                                                      Blocking_SID,
             bs.Serial#                                                  Blocking_Serial_No,
             sblocked.Inst_ID                                            Blocked_Instance_Number,
             sblocked.SID                                                Blocked_SID,
             sblocked.Serial#                                            Blocked_Serial_No,
             oblocked.Owner                                              Blocked_Owner,
             oblocked.Object_Name                                        Blocked_Object_Name,
             oblocked.Data_Object_ID                                     Blocked_Data_Object_ID,
             CASE WHEN oblocked.Data_Object_ID IS NOT NULL AND sblocked.LockWait IS NOT NULL AND sblocked.Row_Wait_Obj# != -1  THEN
               RowIDTOChar(DBMS_RowID.RowID_Create(1, oblocked.Data_Object_ID, sblocked.Row_Wait_File#, sblocked.Row_Wait_Block#, sblocked.Row_Wait_Row#))
             END                                                         Blocked_RowID
     FROM    RawLock l
     JOIN    gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
     LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
     -- Join über der session bekanntes Objekt auf das gewartet wird, alternativ über dem Wait bekanntes Objekt
     LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = DECODE(s.Row_Wait_Obj#, -1, DECODE(s.P2Text, 'object #', s.P2, NULL), s.Row_Wait_Obj#)  -- Objekt, auf das gewartet wird wenn existiert
     LEFT OUTER JOIN gv$Session  sblocked ON l.Type = 'TX' AND sblocked.Blocking_Instance = l.Inst_ID AND sblocked.Blocking_Session = l.SID
     LEFT OUTER JOIN DBA_Objects oblocked ON oblocked.Object_ID = DECODE(sblocked.Row_Wait_Obj#, -1, DECODE(sblocked.P2Text, 'object #', sblocked.P2, NULL), sblocked.Row_Wait_Obj#)
     WHERE  l.Inst_ID    = ?
     AND    l.SID        = ?
     AND    s.Serial#    = ?
     ORDER BY 1
     ", @instance, @sid, @serial_no]

    render_partial :list_session_details_locks
  end

  def show_session_details_temp
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serial_no = params[:serial_no]
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

    render_partial :list_session_details_temp
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

    render_partial
  end

  def list_session_optimizer_environment
    @instance = prepare_param_instance
    @sid      = params[:sid]

    @env = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             Name, #{'SQL_Feature, ' if get_db_version >= '11.2'}IsDefault, Value
      FROM   gV$SES_OPTIMIZER_ENV
      WHERE  Inst_ID = ?
      AND    SID = ?
      ", @instance, @sid]

    render_partial
  end


  # Ermitteln Object aus Parametern von v$session_wait
  def show_session_details_waits_object
    @object = object_nach_wait_parameter(params[:instance], params[:event],
            params[:p1], params[:p1raw], params[:p1text],
            params[:p2], params[:p2raw], params[:p2text],
            params[:p3], params[:p3raw], params[:p3text]
          )
    respond_to do |format|
      format.html {render :html => my_html_escape(@object).html_safe }
    end
  end

  def segment_stat   # Anzeige Auswahl-Dialog für Statistiken
    @stats = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */
          DISTINCT Statistic_Name
        FROM  GV$Segment_Statistics
        WHERE Value != 0"

    render_partial
  end

  
  def show_segment_statistics
    @show_partitions = params[:show_partition_info] == '1'

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
        SELECT /* Panorama-Tool Ramm */
          Inst_ID, Owner, Object_Name, SubObject_Name, Object_Type, SUM(Value) Value
        FROM   (
                SELECT Inst_ID, Owner, Object_Name, #{@show_partitions ? 'SubObject_Name' : 'NULL SubObject_Name'}, Object_Type, Value
                FROM  GV$Segment_Statistics
                WHERE Statistic_Name=?
                AND   Value != 0
               )
        GROUP BY Inst_ID, Object_Type, Owner, Object_Name, SubObject_Name
        ORDER BY Inst_ID, Object_Type, Owner, Object_Name, SubObject_Name",
        params[:statistic_name][:statistic_name]
        ]
    end # get_values

    # Sicherstellen, dass SQL-Sortierung analog der Sortierung in Ruby erfolgt
    PanoramaConnection.sql_execute "ALTER SESSION SET NLS_SORT=BINARY"

    @header = params[:statistic_name][:statistic_name]

    @column_options = []
    @column_options << {:caption=>"Inst",        :data=>"rec.inst_id",             :title=>"RAC-Instance"}
    @column_options << {:caption=>"Type",        :data=>"rec.object_type",         :title=>"Object-Type"}
    @column_options << {:caption=>"Owner",       :data=>"rec.owner",               :title=>"Object-Owner"}
    @column_options << {:caption=>"Name",        :data=>"rec.object_name",         :title=>"Object-Name"}
    @column_options << {:caption=>"Sub-Name",    :data=>"rec.subobject_name",      :title=>"Sub-Object-Name"} if @show_partitions
    @column_options << {:caption=>"Sample",      :data=>proc{|rec| formattedNumber(rec.sample)}, :title=>t(:dba_show_segment_statistics_sample_hint, :default=>'Statistics-value within the sample time'),    :align=>"right"}
    @column_options << {:caption=>"Total",       :data=>proc{|rec| formattedNumber(rec.total)},  :title=>t(:dba_show_segment_statistics_total_hint, :default=>'Statistics-value cumulated since instance startup'),     :align=>"right"}

    data1 = get_values    # Snapshot vor SampleTime
    sampletime = params[:sample_length].to_i
    if sampletime == 0    # Kein Sample gewünscht
      data2 = data1       # selbes Result noch einmal verwenden
    else
      sleep sampletime
      # raw JDBC connection does not cache results
      # PanoramaConnection.get_connection.clear_query_cache # Result-Caching Ausschalten für wiederholten Zugriff
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

    output = gen_slickgrid(@data, @column_options, {:caption=>@header, :width=>"auto",  :max_height=>450})

    respond_to do |format|
      format.html {render :html => output}
    end
  end

  def show_session_waits
    @wait_sums = sql_select_iterator "\
      SELECT /*+ ORDERED USE_NL(s) Panorama Ramm */
             COUNT(*) Anzahl,
             s.Inst_ID,
             DECODE(s.State, 'WAITING', s.Event, 'ON CPU')  Event,
             DECODE(s.State, 'WAITING', s.Wait_Class, NULL) Wait_Class,
             DECODE(s.State, 'WAITING', s.State, NULL)      State,
             #{"SUM(Seconds_In_Wait) Sum_Wait_Time_Seconds," if get_db_version < '11.1'}
             #{"MAX(Seconds_In_Wait) Max_Wait_Time_Seconds," if get_db_version < '11.1'}
             #{"SUM(DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro))/1000000 Sum_Wait_Time_Seconds," if get_db_version >= '11.1'}
             #{"MAX(DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro))/1000000 Max_Wait_Time_Seconds," if get_db_version >= '11.1'}
             COUNT(DISTINCT s.UserName)                     UserName_Count,
             MIN(s.UserName)                                UserName,
             COUNT(DISTINCT s.Module)                       Module_Count,
             MIN(s.Module)                                  Module,
             COUNT(DISTINCT s.Action)                       Action_Count,
             MIN(s.Action)                                  Action
      FROM   gv$Session s
     WHERE   Wait_Class != 'Idle'
     GROUP BY Inst_ID, DECODE(State, 'WAITING', Event, 'ON CPU'),
              DECODE(State, 'WAITING', Wait_Class, NULL), DECODE(State, 'WAITING', State, NULL)
     ORDER BY COUNT(*) DESC, 6 DESC"

    render_partial
  end

  def show_blocking_sessions
    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    record_modifier = proc{|rec|
      rec['waiting_app_desc']  = explain_application_info(rec.module)
      rec['blocking_app_desc'] = explain_application_info(rec.blocking_module)
    }

    @blocking_waits = sql_select_iterator("\
      WITH Locks AS (
              SELECT /* Panorama-Tool Ramm */
                     s.Inst_ID,
                     s.SID,
                     s.Serial# Serial_No,
                     s.SQL_ID,
                     s.SQL_Child_Number,
                     s.Status,
                     DECODE(s.State, 'WAITING', s.Event, 'ON CPU')  Event,
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
                     s.Wait_Time_Micro/1000000 Seconds_Waiting,
                     DECODE(bs.State, 'WAITING', bs.Wait_Time_Micro/1000000) Blocking_Seconds_Waiting,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_Serial_No,
                     bs.Status              Blocking_Status,
                     DECODE(bs.State, 'WAITING', bs.Event, 'ON CPU') Blocking_Event,
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
                     CONNECT_BY_ROOT Blocking_Serial_No        Root_Blocking_Serial_No
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serial_no = blocking_serial_no
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.Serial_No = l.Serial_No
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num", record_modifier)

    render_partial
  end

  def list_waits_per_event
    @instance = params[:instance]
    @event    = params[:event]
    @waits = sql_select_iterator ["\
      SELECT Inst_ID, SID, Serial# Serial_No, Event, Wait_Class,
             P1Text, P1, P1Raw,
             P2Text, P2, P2Raw,
             P3Text, P3, P3Raw,
             #{"Seconds_In_Wait*1000 Wait_Time_MilliSeconds," if get_db_version < '11.1'}
             #{"DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro)/1000 Wait_Time_MilliSeconds," if get_db_version >= '11.1'}
             UserName, State,
             Client_Info, Module, Action,
             SQL_ID, Prev_SQL_ID, SQL_Child_Number, Prev_Child_Number
      FROM   gv$Session s
      WHERE  s.Inst_ID = ?
      AND    ((? = 'ON CPU' AND s.State != 'WAITING') OR s.Event   = ?) ",
      @instance, @event, @event]

    render_partial :list_waits_per_event
  end

  def show_dba_autotask_jobs
    @windows = sql_select_iterator "SELECT c.*,
                                           w.Resource_Plan, w.Schedule_Type, w.Repeat_Interval, w.Window_Priority, w.Comments
                                    FROM   DBA_AUTOTASK_WINDOW_CLIENTS c
                                    LEFT OUTER JOIN DBA_Scheduler_Windows w ON #{"w.Owner = 'SYS' AND " if get_db_version >= '12.1'}w.Window_Name = c.Window_Name
                                   "

    @tasks = sql_select_iterator "SELECT a.*,
                                         EXTRACT(HOUR FROM Mean_Job_Duration)*3600              + EXTRACT(MINUTE FROM Mean_Job_Duration)*60             + EXTRACT(SECOND FROM Mean_Job_Duration)            Mean_Job_Duration_Secs,
                                         EXTRACT(HOUR FROM Mean_Job_CPU)*3600                   + EXTRACT(MINUTE FROM Mean_Job_CPU)*60                  + EXTRACT(SECOND FROM Mean_Job_CPU)                 Mean_Job_CPU_Secs,
                                         EXTRACT(HOUR FROM TOTAL_CPU_LAST_7_DAYS)*3600          + EXTRACT(MINUTE FROM TOTAL_CPU_LAST_7_DAYS)*60         + EXTRACT(SECOND FROM TOTAL_CPU_LAST_7_DAYS)        TOTAL_CPU_LAST_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM TOTAL_CPU_LAST_30_DAYS)*3600         + EXTRACT(MINUTE FROM TOTAL_CPU_LAST_30_DAYS)*60        + EXTRACT(SECOND FROM TOTAL_CPU_LAST_30_DAYS)       TOTAL_CPU_LAST_30_DAYS_Secs,
                                         EXTRACT(HOUR FROM MAX_DURATION_LAST_7_DAYS)*3600       + EXTRACT(MINUTE FROM MAX_DURATION_LAST_7_DAYS)*60      + EXTRACT(SECOND FROM MAX_DURATION_LAST_7_DAYS)     MAX_DURATION_LAST_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM MAX_DURATION_LAST_30_DAYS)*3600      + EXTRACT(MINUTE FROM MAX_DURATION_LAST_30_DAYS)*60     + EXTRACT(SECOND FROM MAX_DURATION_LAST_30_DAYS)    MAX_DURATION_LAST_30_DAYS_Secs,
                                         EXTRACT(HOUR FROM WINDOW_DURATION_LAST_7_DAYS)*3600    + EXTRACT(MINUTE FROM WINDOW_DURATION_LAST_7_DAYS)*60   + EXTRACT(SECOND FROM WINDOW_DURATION_LAST_7_DAYS)  WINDOW_DURATION_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM WINDOW_DURATION_LAST_30_DAYS)*3600   + EXTRACT(MINUTE FROM WINDOW_DURATION_LAST_30_DAYS)*60  + EXTRACT(SECOND FROM WINDOW_DURATION_LAST_30_DAYS) WINDOW_DURATION_30_DAYS_Secs,
                                         j.Job_Runs
                                  FROM   DBA_AutoTask_Client a
                                  JOIN   (SELECT /*+ NO_MERGE */ Client_Name, COUNT(*) Job_Runs
                                          FROM   DBA_AUTOTASK_JOB_HISTORY
                                          GROUP BY Client_Name
                                         ) j ON j.Client_Name = a.Client_Name
                                 "
    render_partial
  end

  def list_dba_autotask_job_runs
    @client_name =  params[:client_name]
    @job_runs = sql_select_iterator ["SELECT j.*,
                                             EXTRACT(HOUR FROM Window_Duration)*3600  + EXTRACT(MINUTE FROM Window_Duration)*60   + EXTRACT(SECOND FROM Window_Duration)  Window_Duration_Secs,
                                             EXTRACT(HOUR FROM Job_Duration)*3600     + EXTRACT(MINUTE FROM Job_Duration)*60      + EXTRACT(SECOND FROM Job_Duration)     Job_Duration_Secs
                                      FROM   DBA_Autotask_Job_History j
                                      WHERE Client_Name = ? ORDER BY Job_Start_Time DESC
                                     ", @client_name]
    render_partial
  end

  def list_database_triggers
    @triggers = sql_select_iterator "\
      SELECT t.*, o.Created, o.Last_DDL_Time, TO_DATE(o.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Spec_TS
      FROM   DBA_Triggers t
      LEFT OUTER JOIN DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Trigger_Name AND o.Object_Type = 'TRIGGER'
      WHERE  t.Base_Object_Type LIKE 'DATABASE%'
      ORDER BY t.Triggering_Event, t.Trigger_Name"
    params[:update_area] = 'content_for_layout'
    render_partial
  end


  def list_accessed_objects
    @instance = params[:instance]
    @sid      = params[:sid]

    @objects = sql_select_iterator ["\
      SELECT /*+ Panorama Ramm */ Owner, Object
      FROM   gv$Access
      WHERE  Inst_ID = ?
      AND    SID     = ?
      ", @instance, @sid]

    render_partial
  end

  def show_server_logs
    @instance = sql_select_one "SELECT Instance_Number FROM v$Instance"

    render_partial
  end

  def list_server_logs
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @log_type     = params[:log_type]
    @incl_filter  = params[:incl_filter]
    @excl_filter  = params[:excl_filter]
    @incl_filter  = nil if @incl_filter == ''
    @excl_filter  = nil if @excl_filter == ''
    @suppress_defaults = params[:suppress_defaults] == '1'

    where_filter = ''
    where_values = []

    unless @log_type == 'all'
      where_filter << " AND TRIM(COMPONENT_ID)=?"
      where_values << @log_type
    end

    if @suppress_defaults
      if @excl_filter
        @excl_filter << '|'
      else
        @excl_filter = ''
      end
      @excl_filter << "Thread 1 advanced to log sequence % (LGWR switch)|"
      @excl_filter << "Current log# % seq# % mem#|"
      @excl_filter << "LNS: Standby redo logfile selected for thread % sequence % for destination LOG_ARCHIVE_DEST|"
      @excl_filter << "Archived Log entry % added for thread % sequence % ID % dest %:"



    end

    if @incl_filter
      where_filter << " AND ("
      incl_filters = @incl_filter.split('|')
      incl_filters.each_index do |i|
        where_filter << " Message_Text LIKE '%'||?||'%'"
        where_filter << " OR " if i < incl_filters.count-1
        where_values << incl_filters[i]
      end
      where_filter << " )"
    end

    if @excl_filter
      @excl_filter.split('|').each do |f|
        where_filter << " AND Message_Text NOT LIKE '%'||?||'%'"
        where_values << f
      end
    end

    if params[:detail]
      # adr_home, Inst_ID removed because not yet existing in 19c
      @result =  sql_select_iterator ["\
      SELECT Originating_Timestamp, Component_ID,
             Message_Type, Message_Level,
             Process_ID, Message_Text, FileName
      FROM   V$DIAG_ALERT_EXT
      WHERE  Originating_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    Originating_Timestamp < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_filter}
      ORDER BY Originating_Timestamp, Record_ID
   ", @time_selection_start, @time_selection_end].concat(where_values)

      render_partial :list_server_logs
    else  # grouping
      trunc_tag = params[:verdichtung][:tag]

      if trunc_tag == 'SS'
        ts_expr = "CAST(Originating_Timestamp AS DATE)"   # trunc second
      else
        ts_expr = "TRUNC(Originating_Timestamp, '#{trunc_tag}')"
      end

      @result =  sql_select_iterator ["\
      SELECT #{ts_expr} Originating_Timestamp, COUNT(*) Records, MAX(CAST(Originating_Timestamp AS DATE))+1/86400 Max_TS_add_1_sec
      FROM   V$DIAG_ALERT_EXT
      WHERE  Originating_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    Originating_Timestamp < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_filter}
      GROUP BY #{ts_expr}
      ORDER BY 1
   ", @time_selection_start, @time_selection_end].concat(where_values)

      render_partial :list_server_log_groups
    end
  end

  def list_patch_history
    begin
      @patches  = sql_select_all "SELECT * FROM sys.Registry$History ORDER BY Action_Time"
    rescue Exception => e
      if e.message['ORA-00942']
        add_statusbar_message "No access allowed on sys.Registry$History! Not all information is shown now!"
        @patches = []
      else
        raise
      end
    end
    @registry = sql_select_iterator "SELECT r.*, TO_DATE(Modified, 'DD-MON-YYYY HH24:MI:SS') date_modified FROM DBA_Registry r ORDER BY Comp_ID"
    if get_db_version >= '12.1'
      @sql_patches = sql_select_all "SELECT * FROM DBA_REGISTRY_SQLPATCH"
    end
    render_partial
  end

  def list_feature_usage
    @feature_usage = sql_select_all "SELECT * FROM DBA_FEATURE_USAGE_STATISTICS"

    # info grouped by management pack
    pack_usage = {}
    @feature_usage.each do |f|
      key = "#{f.dbid} #{pack_from_feature(f.name) }"
      if pack_usage[key].nil?
        pack_usage[key] = { :dbid               => f.dbid,
                            :pack               => pack_from_feature(f.name),
                            :detected_usages    => 0,
                            :currently_used     => 'FALSE'
        }
      end
      pack_usage[key][:detected_usages]   = pack_usage[key][:detected_usages] + f.detected_usages
      pack_usage[key][:currently_used]    = 'TRUE' if f.currently_used == 'TRUE'
      pack_usage[key][:first_usage_date]  = f.first_usage_date if f.first_usage_date && (pack_usage[key][:first_usage_date].nil? || f.first_usage_date <  pack_usage[key][:first_usage_date])
      pack_usage[key][:last_usage_date]   = f.last_usage_date  if f.last_usage_date  && (pack_usage[key][:last_usage_date].nil?  || f.last_usage_date  >  pack_usage[key][:last_usage_date])
    end

    @pack_usage = []
    pack_usage.each do |key, value|
      value.extend TolerantSelectHashHelper
      @pack_usage << value
    end

    render_partial
  end

  def show_trace_files
    @instance = sql_select_one "SELECT Instance_Number FROM v$Instance"
    render_partial
  end

  def list_trace_files
    save_session_time_selection
    @filename_incl_filter         = prepare_param(:filename_incl_filter)
    @filename_excl_filter         = prepare_param(:filename_excl_filter)
    @content_incl_filter          = prepare_param(:content_incl_filter)
    @content_excl_filter          = prepare_param(:content_excl_filter)

    where_string = ''
    where_values = []

    if @filename_incl_filter
      where_string << " AND ("
      incl_filters = @filename_incl_filter.split('|')
      incl_filters.each_index do |i|
        where_string << " f.Trace_Filename LIKE '%'||?||'%'"
        where_string << " OR " if i < incl_filters.count-1
        where_values << incl_filters[i]
      end
      where_string << " )"
    end

    if @filename_excl_filter
      @filename_excl_filter.split('|').each do |f|
        where_string << " AND f.Trace_Filename NOT LIKE '%'||?||'%'"
        where_values << f
      end
    end




    @files = sql_select_iterator ["SELECT f.*
                                   FROM   gv$Diag_Trace_File f
                                   WHERE  f.Change_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_start)}')
                                   AND    f.Change_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(@time_selection_end)}')
                                   #{where_string}
                                   ORDER BY f.Change_Time
                                  ", @time_selection_start, @time_selection_end].concat(where_values)

    # GV_$DIAG_TRACE_FILE
    # GV_$DIAG_TRACE_FILE_CONTENTS
    render_partial
  end

  def list_trace_file_content
    @instance                     = prepare_param_instance
    @adr_home                     = prepare_param(:adr_home)
    @trace_filename               = prepare_param(:trace_filename)
    @con_id                       = prepare_param(:con_id)
    @dont_show_sys                = prepare_param(:dont_show_sys)
    @dont_show_stat               = prepare_param(:dont_show_stat)
    @org_update_area              = prepare_param(:update_area)
    @max_trace_file_lines_to_show = prepare_param_int(:max_trace_file_lines_to_show, default: 10000)
    @first_or_last_lines          = prepare_param(:first_or_last_lines, default: 'first')

    counts = sql_select_first_row ["SELECT COUNT(*) lines, MAX(Line_Number) Max_Line_Number
                                    FROM   gv$Diag_Trace_File_Contents c
                                    WHERE  c.Inst_ID        = ?
                                    AND    c.ADR_Home       = ?
                                    AND    c.Trace_FileName = ?
                                    AND    c.Con_ID         = ?
                                    ORDER BY c.Line_Number
                                   ", @instance, @adr_home, @trace_filename, @con_id]
    @trace_file_line_count = counts.lines
    if @trace_file_line_count > @max_trace_file_lines_to_show
      add_statusbar_message("Trace file #{@trace_filename} contains #{fn(@trace_file_line_count)} rows!\nEvaluating only the #{@first_or_last_lines} #{fn(@max_trace_file_lines_to_show)} rows of the file.")
    end

    rownum_condition, row_num_value = lambda{
      if @first_or_last_lines == 'first'
        return "Row_Num < ?", @max_trace_file_lines_to_show + 1
      else
        return "Row_Num > ?", @trace_file_line_count - @max_trace_file_lines_to_show
      end
    }.call

    content_iter = sql_select_iterator ["SELECT x.*, NULL elapsed_ms, Null delay_ms, NULL parse_line_no, NULL SQL_ID
                                         FROM   (SELECT /*+ NO_MERGE */ c.*, c.Serial# Serial_No, RowNum Row_Num
                                                 FROM   gv$Diag_Trace_File_Contents c
                                                 WHERE  c.Inst_ID        = ?
                                                 AND    c.ADR_Home       = ?
                                                 AND    c.Trace_FileName = ?
                                                 AND    c.Con_ID         = ?
                                                 ORDER BY c.Line_Number
                                                ) x
                                         WHERE  #{rownum_condition}
                                      ", @instance, @adr_home, @trace_filename, @con_id, row_num_value]

    @content = []
    all_cursors = {}
    sys_cursors = {}
    sys_sql_lines = false                                                       # mark the lines between PARSING IN CURSOR # and END OF STMT
    sys_binds     = false                                                       # mark the following lines as binds of SYS SQL
    last_tim      = nil                                                         # last timestamp mark

    content_iter.each do |line|
      if line.payload.nil?
        line.payload = ''                                                       # Ensure line.payload is valid
      else
        line.payload = line.payload.strip                                       # remove leading and trailing blanks or line feeds
      end

      # calculate elapsed time
      pattern = ',e='
      pattern = ' ela= ' if line.payload['WAIT #']
      line['elapsed_ms'] = line.payload[pattern] ? line.payload[line.payload.index(pattern)+pattern.length, 20].split(' ')[0].split(',')[0].to_i/1000.0 : nil rescue nil
      line['elapsed_ms'] = nil if line['elapsed_ms'] == 0

      # calculate timestamp delay
      tim = line.payload['tim='] ? line.payload[line.payload.index('tim=')+4, 20].split(' ')[0].split(',')[0] : nil rescue nil
      unless tim.nil?
        line['delay_ms'] = last_tim.nil? ? nil : (tim.to_i - last_tim) / 1000.0 rescue nil
        last_tim = tim.to_i
      end

      cursor_id = nil                                                           # default if no calculation of cursor_id is needed
      # cursor id starts with # and ends with : except for PARSING IN CURSOR
      cursor_id = line.payload['#'] && line.payload[':']? line.payload[line.payload.index('#')+1, 20].split(':')[0] : nil rescue nil
      cursor_id = nil if cursor_id.to_i == 0                                    # no trailing : found for cursor_id
      if line.payload['PARSING IN CURSOR #'] || line.payload['STAT #']
        cursor_id = line.payload[line.payload.index('#')+1, 20].split(' ')[0]   # in this case cursor id ends with blank
      end

      if line.payload['PARSING IN CURSOR #']                                    # Remember the first occurrence of this sql
        all_cursors[cursor_id] = { parse_line_no: line.line_number, sql_id: line.payload[line.payload.index('sqlid=')+7, 20].split("'")[0] }
      end

      if @dont_show_sys == '1'
        sys_binds = false if cursor_id                                          # Bind lines end with next valid cursor id in line
        if line.payload['PARSING IN CURSOR #']
          uid = line.payload[line.payload.index('uid=')+4, 20].split[0]
          if uid == '0'
            sys_cursors[cursor_id] = 1                                          # mark cursor as sys cursor
            sys_sql_lines = true                                                # suppress the following lines
          else
            sys_cursors.delete(cursor_id) if sys_cursors.has_key?(cursor_id)    # next reuse of cursor with user != SYS end exclusion
          end
        end
      end

      if !sys_cursors.has_key?(cursor_id) && !sys_sql_lines && !sys_binds &&
        !(@dont_show_stat == '1' && line.payload['STAT #'] ) &&
        !(@dont_show_sys  == '1' && (line.payload == '' || line.payload == '=====================' ) ) # suppress empty lines for @dont_show_sys

        if all_cursors.has_key?(cursor_id)                                      # we met PARSING IN CURSOR for this cursor in file before
          line['parse_line_no'] = all_cursors[cursor_id][:parse_line_no]
          line['sql_id']        = all_cursors[cursor_id][:sql_id]
        end
        @content << line
      end

      # suppress known sys cursor actions
      sys_sql_lines = false if @dont_show_sys == '1' && line.payload['END OF STMT'] # now show all not sys cursor lines
      sys_binds = true      if @dont_show_sys == '1' && line.payload['BINDS #'] && sys_cursors.has_key?(cursor_id)

      all_cursors.delete(cursor_id) if line.payload['CLOSE #'] && all_cursors.has_key?(cursor_id)    # forget all about this cursor

    end

    render_partial
  end

  def list_trace_file_cursor_sql_text
    @instance       = prepare_param_instance
    @adr_home       = prepare_param(:adr_home)
    @trace_filename = prepare_param(:trace_filename)
    @con_id         = prepare_param(:con_id)
    @parse_line_no  = prepare_param :parse_line_no
    @sql_id         = prepare_param :sql_id
    @line_number    = prepare_param_int :line_number
    @cursor_id      = prepare_param :cursor_id

    if @parse_line_no
      content = sql_select_all [ "WITH lines AS (SELECT *
                                               FROM   gv$Diag_Trace_File_Contents
                                               WHERE  Inst_ID        = ?
                                               AND    ADR_Home       = ?
                                               AND    Trace_FileName = ?
                                               AND    Con_ID         = ?
                                               AND    Line_Number    >= ?
                                               AND    Line_Number    < ?
                                              ),
                                     end_line AS (SELECT MIN(l.Line_Number) Line_Number
                                                  FROM   Lines l
                                                  WHERE  l.Line_Number > ?
                                                  AND  Payload LIKE 'END OF STMT%'
                                                 )
                                SELECT l.Line_Number, l.Payload
                                FROM   Lines l
                                CROSS JOIN end_line
                                WHERE  l.Line_Number > ?
                                AND    l.Line_Number < end_line.line_number
                               ", @instance, @adr_home, @trace_filename, @con_id, @parse_line_no, @line_number, @parse_line_no, @parse_line_no]
    else
      content = sql_select_all [ "WITH lines AS (SELECT *
                                               FROM   gv$Diag_Trace_File_Contents
                                               WHERE  Inst_ID        = ?
                                               AND    ADR_Home       = ?
                                               AND    Trace_FileName = ?
                                               AND    Con_ID         = ?
                                               AND    Line_Number    < ?
                                              ),
                                     start_line AS (SELECT MAX(Line_Number) Line_Number
                                                    FROM   Lines
                                                    WHERE  Payload LIKE 'PARSING IN CURSOR ##{@cursor_id}%'
                                                   ),
                                     end_line AS (SELECT MIN(l.Line_Number) Line_Number
                                                  FROM   Lines l
                                                  CROSS JOIN start_line
                                                  WHERE  l.Line_Number > start_line.line_number
                                                  AND  Payload LIKE 'END OF STMT%'
                                                 )
                                SELECT l.Line_Number, l.Payload
                                FROM   Lines l
                                CROSS JOIN start_line
                                CROSS JOIN end_line
                                WHERE  l.Line_Number > start_line.line_number
                                AND    l.Line_Number < end_line.line_number
                               ", @instance, @adr_home, @trace_filename, @con_id, @line_number]
    end
    result = ''
    content.each do |rec|
      result << rec.payload
    end

    prefix = result == '' ? "No SQL found for cursor ##{@cursor_id} in trace file up to this line #{@line_number}" : "-- SQL for cursor ##{@cursor_id} found PARSING IN CURSOR at line #{content[0].line_number-1}"

    respond_to do |format|
      format.html {render :html => render_code_mirror("#{prefix}\n\n#{result}") }
    end
  end

  def list_os_statistics
    @osstats = sql_select_iterator "SELECT * FROM gv$OSStat ORDER BY Stat_Name, Inst_ID"
    render_partial
  end

  def resource_limits
    @resource_limits = sql_select_all ["
       SELECT rl.*
       FROM   gv$Resource_Limit rl
       ORDER BY rl.Resource_Name, rl.Inst_ID
      "]
    if @resource_limits.length == 0
      show_popup_message("No content available in gv$Resource_Limit for your connection!
  For PDB please connect to database with CDB-user instead of PDB-user.")
    else
      render_partial
    end
  end

  def refresh_dashboard_ash
    instance                  = prepare_param_instance
    @dbid                      = prepare_param_dbid
    hours_to_cover            = prepare_param(:hours_to_cover).to_f
    last_refresh_time_string  = prepare_param :last_refresh_time_string
    smallest_timestamp_ms     = prepare_param_int :smallest_timestamp_ms
    window_width              = prepare_param_int :window_width

    where_string = ''
    where_values = []

    if last_refresh_time_string                                                 # add refresh delta to existing data
      where_string << "WHERE TO_CHAR(Sample_Time, 'YYYY/MM/DD HH24:MI:SS') > ?"
      where_values << last_refresh_time_string
    else                                                                        # Initially read data
      where_string << "WHERE Sample_Time > SYSDATE - ?/24"
      where_values << hours_to_cover
    end

    if instance
      where_string << " AND Inst_ID = ?"
      where_values << instance
    end

    # Calculate granularity of points in diagram
    smallest_timestamp = nil
    if smallest_timestamp_ms.nil?                                               # first time read data (or none existing until now)
      smallest_timestamp = sql_select_one ["\
        SELECT MIN(Sample_Time) FROM gv$Active_Session_History #{where_string}
      "].concat(where_values)
      smallest_timestamp = Time.now-300 if smallest_timestamp.nil?              # use 5 minutes if no data in gv$Active_Session_History, especially for test
    else
      smallest_timestamp = Time.at(smallest_timestamp_ms/1000).utc
    end
    db_time_now = sql_select_one "SELECT SYSDATE FROM DUAL"
    seconds_coverered = db_time_now - smallest_timestamp
    grouping_secs = (seconds_coverered/(window_width/2)).round
    grouping_secs = 1 if grouping_secs < 1
    grouping_secs = grouping_secs.to_f                                          # ensure exact values after division in SQL
    ash_data = sql_select_all ["\
      SELECT MAX(Sample_Time_String) OVER (PARTITION BY Grouping) Sample_Time_String, /* max. timestamp over all wait classes in group */
             Wait_Class, Sessions
      FROM  (
             SELECT Grouping,
                    Wait_Class,
                    TO_CHAR(MAX(Sample_Time_Date), 'YYYY/MM/DD HH24:MI:SS') Sample_Time_String,
                    ROUND(AVG(Sessions), 2) Sessions
             FROM   (SELECT Sample_Time_Date,
                            Wait_Class,
                            COUNT(*) Sessions,
                            ROUND(((Sample_Time_Date - date '1970-01-01')*86400) / ?) Grouping /* grouping criteria for condensed data due to window width */
                     FROM   (SELECT CAST (Sample_Time AS DATE) Sample_Time_Date,
                                    COALESCE(Wait_Class, DECODE(Session_State, 'ON CPU', 'CPU', '[Unknown]')) Wait_Class
                             FROM   gv$Active_Session_History
                             #{where_string}
                            )
                     GROUP BY Sample_Time_Date, Wait_Class /* group by seconds to get number of waiting sessions for timestamp */
                    )
             GROUP BY Grouping, Wait_Class
            )
      ORDER BY Sample_Time_String, Wait_Class
    "].concat([grouping_secs]).concat(where_values)

    ash_data.each do |a|
      a.sessions = a.sessions.to_f if a.sessions.instance_of? BigDecimal
    end
    render json: { grouping_secs: grouping_secs, ash_data: ash_data }
  end

  def refresh_top_session_sql
    @instance                 = prepare_param_instance
    @dbid                     = prepare_param_dbid
    hours_to_cover            = prepare_param(:hours_to_cover).to_f
    last_refresh_time_string  = prepare_param :last_refresh_time_string
    start_range_ms            = prepare_param(:start_range_ms).to_i
    end_range_ms              = prepare_param(:end_range_ms).to_i

    where_string = ''
    where_values = []

    if start_range_ms != 0 && end_range_ms != 0                                 # Manual selection in chart
      where_string << "WHERE TO_CHAR(h.Sample_Time, 'YYYY/MM/DD HH24:MI:SS') >= ? AND TO_CHAR(h.Sample_Time, 'YYYY/MM/DD HH24:MI:SS') <= ?"
      where_values << Time.at(start_range_ms/1000).utc.strftime("%Y/%m/%d %H:%M:%S")
      where_values << Time.at(end_range_ms/1000).utc.strftime("%Y/%m/%d %H:%M:%S")

      # Possible CPU hang on Oracle 12.1 if executing simple SELECT MIN(Sample_Time) FROM gv$Active_Session_History, Doc ID 2299480.1
      # access per instance fixes this problem
      min_ash_time = sql_select_one ["SELECT MIN(Min_Sample_Time)
                                      FROM   (
                                              SELECT Inst_ID,
                                                  (SELECT MIN(h.Sample_Time) FROM gv$Active_Session_history h WHERE h.Inst_ID = i.Inst_ID) Min_Sample_Time
                                              FROM gv$Instance i
                                              #{" WHERE Inst_ID = ?" if @instance}
                                             )
                                      "].concat(@instance ? [@instance] : [])
      if min_ash_time > Time.at(start_range_ms/1000).utc
        show_popup_message("Needed data has already been flushed from ASH in SGA!
Please use function at menu 'Session-Waits/Historic' instead for analysis with access on persisted ASH in AWR.

Oldest remaining ASH record in SGA is from #{localeDateTime(min_ash_time)} but considered time period starts at #{localeDateTime(Time.at(start_range_ms/1000).utc)}")
      end
    else
      if last_refresh_time_string
        where_string << "WHERE TO_CHAR(h.Sample_Time, 'YYYY/MM/DD HH24:MI:SS') > ?"
        where_values << last_refresh_time_string
      else
        where_string << "WHERE h.Sample_Time > SYSDATE - ?/24"
        where_values << hours_to_cover
      end
    end

    if @instance
      where_string << " AND h.Inst_ID = ?"
      where_values << @instance
    end

    @top_sessions = sql_select_all ["\
      SELECT h.*,
             COALESCE(s.UserName, (SELECT u.UserName FROM #{get_db_version >= '12.1' ? "CDB_Users /* see users of all PDBs if possible */" : "All_Users"} u WHERE u.User_ID = h.User_ID #{" AND u.Con_ID = h.Con_ID" if get_db_version >= '12.1'})) UserName,
             s.OSUser
      FROM   (
              SELECT /*+ NO_MERGE */ *
              FROM   (
                      SELECT QInst_ID, QSession_ID, QSession_Serial_No, MIN(User_ID) User_ID, MIN(Machine) Machine,
                             MAX(SQL_ID)            KEEP (DENSE_RANK LAST ORDER BY Max_Wait_SQL) Max_SQL_ID,
                             MAX(SQL_Child_Number)  KEEP (DENSE_RANK LAST ORDER BY Max_Wait_SQL) Max_SQL_Child_Number,
                             MAX(Module)            KEEP (DENSE_RANK LAST ORDER BY Max_Wait_Module) Max_Module,
                             MAX(Action)            KEEP (DENSE_RANK LAST ORDER BY Max_Wait_Action) Max_Action,
                             COUNT(*) Wait_Time_secs, MIN(Sample_Time) First_Occurrence, MAX(Sample_Time) Last_Occurrence,
                             COUNT(DISTINCT PQ_Session) PQ_Sessions
                             #{", Con_ID" if get_db_version >= '12.1' }
                      FROM   (SELECT h.*,
                                     COUNT(*) OVER (PARTITION BY QInst_ID, QSession_ID, QSession_Serial_No, SQL_ID, SQL_Child_Number) Max_Wait_SQL,
                                     COUNT(*) OVER (PARTITION BY QInst_ID, QSession_ID, QSession_Serial_No, Module) Max_Wait_Module,
                                     COUNT(*) OVER (PARTITION BY QInst_ID, QSession_ID, QSession_Serial_No, Action) Max_Wait_Action
                              FROM   (SELECT h.*,
                                             NVL(QC_Instance_ID, Inst_ID)                   QInst_ID,
                                             NVL(QC_Session_ID, Session_ID)                 QSession_ID,
                                             NVL(QC_Session_Serial#, Session_Serial#)       QSession_Serial_No,
                                             DECODE(QC_Session_ID, NULL, NULL, Inst_ID||','||Session_ID||','||Session_Serial#) PQ_Session
                                      FROM   gv$Active_Session_History h
                                      #{where_string}
                                     ) h
                             )
                      GROUP BY QInst_ID, QSession_ID, QSession_Serial_No#{", Con_ID" if get_db_version >= '12.1' }
                      ORDER BY Wait_Time_secs DESC
                     ) h
              WHERE  RowNum <= 10
             ) h
      LEFT OUTER JOIN gv$Session s ON s.Inst_ID = h.QInst_ID and s.SID = h.QSession_ID AND s.Serial# = h.QSession_Serial_No
      ORDER BY Wait_Time_secs DESC
    "].concat(where_values)

    @first_session_time = nil
    @last_session_time  = nil
    @top_sessions.each do |s|
      @first_session_time = s.first_occurrence if  @first_session_time.nil? || @first_session_time > s.first_occurrence
      @last_session_time  = s.last_occurrence  if  @last_session_time.nil?  || @last_session_time  < s.last_occurrence
    end

    @top_sqls = sql_select_all ["\
      SELECT h.*, SUBSTR(sql.SQL_Text, 1, 80) SQL_SubText, s.OSUSer,
             CASE WHEN User_IDs = 1 THEN (SELECT u.UserName FROM #{get_db_version >= '12.1' ? "CDB_Users /* see users of all PDBs if possible */" : "All_Users"} u WHERE u.User_ID = h.Min_User_ID #{" AND u.Con_ID = h.Con_ID" if get_db_version >= '12.1'}) END UserName
      FROM   (
              SELECT /*+ NO_MERGE */ *
              FROM   (
                      SELECT Inst_ID, SQL_ID,
                             COUNT(DISTINCT SQL_Child_Number) SQL_Child_Count,
                             COUNT(*) Wait_Time_Secs,
                             COUNT(DISTINCT QInst_ID||','||QSession_ID||','||QSession_Serial_No) Sessions,
                             COUNT(DISTINCT PQ_Session)   PQ_Sessions,
                             MIN(QInst_ID)                Min_QInst_ID,
                             MIN(QSession_ID)             Min_QSession_ID,
                             MIN(QSession_Serial_No)      Min_QSession_Serial_No,
                             COUNT(DISTINCT User_ID)      User_IDs,
                             MIN(User_ID)                 Min_User_ID,
                             MIN(Sample_Time) First_OCcurrence, MAX(Sample_Time) Last_Occurrence
                             #{", Con_ID" if get_db_version >= '12.1' }
                      FROM   (SELECT h.*,
                                     NVL(QC_Instance_ID, Inst_ID)                   QInst_ID,
                                     NVL(QC_Session_ID, Session_ID)                 QSession_ID,
                                     NVL(QC_Session_Serial#, Session_Serial#)       QSession_Serial_No,
                                     DECODE(QC_Session_ID, NULL, NULL, Inst_ID||','||Session_ID||','||Session_Serial#) PQ_Session
                              FROM   gv$Active_Session_History h
                              #{where_string} AND SQL_ID IS NOT NULL
                             ) h
                      GROUP BY Inst_ID, SQL_ID#{", Con_ID" if get_db_version >= '12.1' }
                      ORDER BY Wait_Time_secs DESC
                     ) h
              WHERE  RowNum <= 10
             ) h
      LEFT OUTER JOIN gv$SQLArea sql ON sql.Inst_ID = h.Inst_ID AND sql.SQL_ID = h.SQL_ID
      LEFT OUTER JOIN gv$Session s ON s.Inst_ID = h.Min_QInst_ID and s.SID = h.Min_QSession_ID AND s.Serial# = h.Min_QSession_Serial_No
      ORDER BY Wait_Time_secs DESC
    "].concat(where_values)

    render_partial
  end

  def list_dba_scheduler_jobs
    @jobs = sql_select_iterator "SELECT j.*,
                                        EXTRACT(DAY FROM j.Last_Run_Duration * 86400 * 1000)/1000 Last_Run_Duration_Seconds,
                                        EXTRACT(DAY FROM j.Schedule_Limit    * 86400 * 1000)/1000 Schedule_Limit_Seconds,
                                        EXTRACT(DAY FROM j.Max_Run_Duration  * 86400 * 1000)/1000 Max_Run_Duration_Seconds,
                                        NVL(j.Job_Type, p.Program_Type)     Job_or_Program_Type,
                                        NVL(j.Job_Action, p.Program_Action) Job_or_Program_Action
                                 FROM   DBA_Scheduler_Jobs j
                                 LEFT OUTER JOIN DBA_Scheduler_Programs p ON p.Owner = j.Program_Owner AND p.Program_Name = j.Program_Name
                                "
    render_partial
  end

  def list_dba_scheduler_job_run_details
    @owner        = prepare_param :owner
    @job_name     = prepare_param :job_name
    @job_subname  = prepare_param :job_subname

    where_string = ''
    where_values = []
    if @job_subname
      where_string << " AND Job_SubName = ?"
      where_values << @job_subname
    end

    @job_runs = sql_select_iterator ["SELECT d.*,
                                             Error# Error_no,
                                             EXTRACT(DAY FROM d.Run_Duration * 86400 * 1000)/1000 Run_Duration_Seconds,
                                             EXTRACT(DAY FROM d.CPU_Used     * 86400 * 1000)/1000 CPU_Used_Seconds
                                      FROM   DBA_Scheduler_Job_Run_Details d
                                      WHERE  Owner = ?
                                      AND    Job_Name = ?
                                      #{where_string}
                                     ", @owner, @job_name].concat(where_values)
    render_partial
  end
end # Class
