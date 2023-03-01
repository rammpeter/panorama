# encoding: utf-8
module DbaHelper
  
  # Ermitteln Object-Bezeichnung nach File-No. und Block-No.  
  def object_nach_file_und_block(fileno, blockno, instance=nil)
    # Erster Test, das Objekt ueber den DB-Cache zu identifizieren (schneller)

    wherestr = ""
    whereval = []

    if instance
      wherestr << " AND b.Inst_ID = ?"
      whereval << instance
    end

    result = sql_select_all ["\
      SELECT /*+ ORDERED USE_NL(b o) */ /* Panorama-Tool Ramm */
             o.Owner||'.'||o.Object_Name||':'||o.SubObject_Name||' ('||o.Object_Type||')'  Value  
      FROM   gv$bh b
      JOIN   DBA_Objects o ON o.data_object_id = b.objd
      WHERE  b.objd           < power(2,22)
      AND    b.status         != 'free'                               
      AND    b.file#          = ?                                     
      AND    b.block#         = ?                                     
      AND    RowNum           < 2 /* ein Cluster-Node mit Treffer reicht */
      #{wherestr}
    ",
    fileno.to_i, blockno.to_i
    ].concat(whereval)

    # Zweiter Versuch über DBA_Extents, wenn gesuchter Block nicht im Cache
    if result.length == 0
      result = sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
               Owner||'.'||SEGMENT_NAME||':'||Partition_Name||' ('||Segment_Type||')'  Value  
        FROM   DBA_Extents e                                            
        WHERE  e.File_ID = ?                                            
        AND    ? BETWEEN e.BLOCK_ID AND e.BLOCK_ID + e.BLOCKS -1", 
      fileno.to_i, blockno.to_i
      ]
    end
    if result.length > 0
      result[0].value
    else 
      nil   # Kein ergebnis gefunden
    end
  end

  # Ermitteln des Betroffenen Objektes aus Parametern von v$session_wait
  def object_nach_wait_parameter(instance, event, p1, p1raw, p1text, p2, p2raw, p2text, p3, p3raw, p3text)
    wordsize = PanoramaConnection.db_wordsize    # Wortbreite in Byte
    case
    when (p1text=="file#" || p1text=="file number") && (p2text=="block#" || p2text=="first dba") then
      result = object_nach_file_und_block(p1, p2, instance)
      result = "Nothing found for p1=#{p1}, p2=#{p2}, instance=#{instance}" unless result
      result
    when p1text=="address" && p2text=="number" && p3text=='tries' then
      p1raw = p1.to_i.to_s(16).upcase unless p1raw   # Rück-Konvertierung aus p1 wenn raw nicht belegt ist
      # Auslesen Objekt über Cache-Block
      begin
      result = sql_select_one ["\
        SELECT /*+ ORDERED USE_NL(b o) */ /* Panorama-Tool Ramm */
               o.Owner||'.'||o.Object_Name||':'||o.SubObject_Name||' ('||o.Object_Type||')'  Value
        FROM   X$BH b
        JOIN   DBA_Objects o ON o.data_object_id = b.obj
        WHERE  b.hladdr = HexToRaw(?)
        AND    RowNum           < 2 /* ein Cluster-Node mit Treffer reicht */ ",
        p1raw ]
        result = "Nothing found in DB-Cache (X$BH) for HLAddr = #{p1raw}" unless result
      rescue Exception=>e
        alert_exception(e, x_dollar_bh_solution_text, :html)
      end
      result
    when p1text == "idn" && p2text == "value" && p3text == "where"
      if event.match('cursor: ')
        cursor_rec = sql_select_first_row ["SELECT /*+ Panorama-Tool Ramm */ SQL_ID, Parsing_Schema_Name, SQL_Text FROM gv$SQL WHERE Inst_ID=? AND Hash_Value=?", instance, p1.to_i]
        "Blocking-SID=#{p2.to_i/2**32 & 2**16-1}, Cursor-Hash-Value=#{p1.to_i} SQL-ID='#{cursor_rec.sql_id if cursor_rec}', User=#{cursor_rec.parsing_schema_name if cursor_rec}, #{cursor_rec.sql_text if cursor_rec}"
      else   # Mutex etc. e.g. 'library cache: mutex X'
        # P1 = “idn” = Unique Mutex Identifier. Hash value of library cache object protected by mutex or hash bucket number.
        # P2 = “value” = “Blocking SID | Shared refs” = SID: bitand(p2/power(2,32),power(2,16)-1). This session is currently holding the mutex exclusively or modifying it. Lower bytes represent the number of shared references when the mutex is in-flux
        # Source for p2 SID-Interpretation: https://fritshoogland.files.wordpress.com/2020/04/mutexes-2.pdf
        # P3 = “where” = “Location ID | Sleeps” = Top 2(4) bytes contain location in code (internal identifier) where mutex is being waited for. Lower bytes contain the number of sleeps for this mutex. These bytes not populated on some platforms, including Linux
        lc_obj_name = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ Type||' '||Owner||'.'||Name FROM gv$DB_Object_Cache WHERE Inst_ID=? AND Hash_Value=?", instance, p1.to_i]
        "Object=#{lc_obj_name}, Blocking-SID=#{p2.to_i/2**32 & 2**16-1}, number of shared references=#{p2.to_i%2**(4*wordsize)}, Location-ID=#{p3.to_i/2**(4*wordsize)}, Number of Sleeps=#{p3.to_i%2**(4*wordsize)} "
      end
    when event.match('library cache') && p1text=="handle address" then
      # TODO: move to
      # select * from v$libcache_locks where object_handle = to_char(21096197416,'fm000000000000000X') -- p1raw
      # select * from v$db_object_cache where addr = to_char(21096197416,'fm000000000000000X') -- p1raw
      begin
        result = sql_select_one ["SELECT 'handle_address: Owner='''||kglnaown||''', Object='''||kglnaobj||''''
                                FROM   x$kglob
                                WHERE kglhdadr=HEXToRaw(TRIM(TO_char(?,'XXXXXXXXXXXXXXXX')))", p1]
        result = "Nothing found in x$kglob for p1" unless result
      rescue Exception
        result = "Access denied on x$kglob"
      end
      oc = sql_select_first_row ["SELECT * FROM v$DB_Object_Cache WHERE Addr = TO_CHAR(?, 'fm000000000000000X')", p1]
      if oc.nil?
        result << ", No hit in v$DB_Object_Cache for p1"
      else
        result << ", Owner='#{oc.owner}'"           if oc.owner
        result << ", Name='#{oc.name[0,100]}'"      if oc.name
        result << ", DB-Link='#{oc.db_link}'"       if oc.db_link
        result << ", Namespace='#{oc.namespace}'"   if oc.namespace
        result << ", Type='#{oc.type}'"             if oc.type
      end
      result << ", Mode='#{(p3.to_i % 2**32) & 2**16-1}'"
      begin
        ns_id = (p3.to_i % 2**32)/2**16
        result << ", Namespace-ID='#{ns_id}'"
        ns = sql_select_one ["SELECT KGLSTDSC FROM x$kglst WHERE INDX=? and KGLSTTYP='NAMESPACE'", ns_id]
        result << ", Namespace='#{ns}'"
      rescue Exception
        result << ", Access denied on x$kglst"
      end
      result
    when p1text == 'channel context' # reliable message
      sql = "\
SELECT name_ksrcdes
FROM   x$ksrcdes
WHERE  indx = (SELECT name_ksrcctx FROM x$ksrcctx WHERE addr like '%'||TRIM(TO_CHAR(?, 'XXXXXXXXXXXXXXXX'))||'%')"
      begin
        result = "Channel name = #{sql_select_one [sql, p1]}"
      rescue Exception => e
        result = "Unable to execute SQL! Please retry as SYSDBA. \n\n#{e.message}"
      end
    when p1text == 'name|mode' && p2text == 'object #'
      result = "Lock type = '#{((p1.to_i & -16777216 ) / 16777215).chr}#{((p1.to_i & 16711680 ) / 65535).chr}'\n"
      result << "Lock mode = #{p1.to_i & 65535} (#{lock_modes(p1.to_i & 65535)})\n"
      obj_rec = sql_select_first_row(["SELECT Owner, Object_Name, SubObject_Name FROM DBA_Objects WHERE Object_ID = ?", p2.to_i])
      result << "Object = #{obj_rec.owner}.#{obj_rec.object_name}"
      result << " (#{obj_rec.subobject_name})" if obj_rec.subobject_name
      result
    else
      "[No object can be determined for parameters p1, p2]"
    end
  end

    # Erweitern Zuweisungen und Vergleiche um Spaces, damit an dieser Stelle umgebrochen werden kann
  def expand_compare_spaces(origin)
    return nil unless origin
    ["=", "!=", "<>", "<=", ">="].each do |search_str|                          # Iteration über mit Space zu expandierende Ausdrücke
      match_string = /[^ |!|<|>]#{search_str}[^ |!|<|>]/                        # Ausschluss von Vorgängern/Nachfolgern
      while origin.match(match_string)                                          # noch Treffer zu finden?
        origin.sub!(match_string, origin.match(match_string)[0].sub(search_str, " #{search_str} "))     # Expandieren mit Spaces
      end
    end
    origin
  end

  def get_sql_monitor_count(dbid, instance, sql_id, time_selection_start, time_selection_end, sid=nil, serial_no=nil)
    if get_db_version >= '11.1' && PackLicense.tuning_pack_licensed?
      where_string_sga = ''
      where_string_awr = ''
      where_values = []

      if instance
        where_string_sga << " AND Inst_ID = ?"
        where_string_awr << " AND Instance_Number = ?"
        where_values << instance
      end

      if sql_id
        where_string_sga << " AND SQL_ID = ?"
        where_string_awr << " AND Key1 = ?"
        where_values << sql_id
      end

      if sid
        where_string_sga << " AND SID = ?"
        where_string_awr << " AND Session_ID = ?"
        where_values << sid
      end

      if serial_no
        where_string_sga << " AND Session_Serial# = ?"
        where_string_awr << " AND Session_Serial# = ?"
        where_values << serial_no
      end

      sql_monitor_reports_count = sql_select_one ["\
        SELECT COUNT(*) Amount
        FROM   gv$SQL_Monitor
        WHERE  Process_Name = 'ora' /* Foreground process, not PQ-slave */
        AND    (    First_Refresh_Time BETWEEN TO_DATE(?, '#{sql_datetime_mask(time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(time_selection_end)}')
                OR  Last_Refresh_Time  BETWEEN TO_DATE(?, '#{sql_datetime_mask(time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(time_selection_end)}')
               )
        #{where_string_sga}
        ", time_selection_start, time_selection_end, time_selection_start, time_selection_end].concat(where_values)

      if get_db_version >= '12.1'                                               # Also look for historic reports
        reports_count = sql_select_one ["\
          SELECT COUNT(*) Amount
          FROM   DBA_HIST_Reports
          WHERE  DBID           = ?
          AND    Component_Name = 'sqlmonitor'
          AND    (    Period_Start_Time BETWEEN TO_DATE(?, '#{sql_datetime_mask(time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(time_selection_end)}')
                  OR  Period_End_Time   BETWEEN TO_DATE(?, '#{sql_datetime_mask(time_selection_start)}') AND TO_DATE(?, '#{sql_datetime_mask(time_selection_end)}')
                 )
          #{where_string_awr}
          ", dbid, time_selection_start, time_selection_end, time_selection_start, time_selection_end].concat(where_values)
        sql_monitor_reports_count += reports_count
      end
      sql_monitor_reports_count
    else
      0
    end
  end

  def x_dollar_bh_solution_text
    "
Possibly missing access rights on table X$BH!
Possible solutions:
Alternative 1: Connect with role SYSDABA
Alternative 2: Execute as user SYS
> create view x_$bh as select * from x$bh;
> grant select on x_$bh to public;
> create public synonym x$bh for sys.x_$bh;
This way X$BH becomes available with role SELECT ANY DICTIONARY
"
  end


end