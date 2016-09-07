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
    wordsize = get_db_wordsize    # Wortbreite in Byte
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
          result = "You don't have the right to access view X$BH ! Function not available."
        end
        result
      when p1text == "idn" && p2text == "value" && p3text == "where"
        if event.match('cursor: ') then
          cursor_rec = sql_select_first_row ["SELECT /*+ Panorama-Tool Ramm */ SQL_ID, Parsing_Schema_Name, SQL_Text FROM gv$SQL WHERE Inst_ID=? AND Hash_Value=?", instance, p1.to_i]
          "Blocking-SID=#{p2.to_i/2**(4*get_db_wordsize) }, Cursor-Hash-Value=#{p1.to_i} SQL-ID='#{cursor_rec.sql_id if cursor_rec}', User=#{cursor_rec.parsing_schema_name if cursor_rec}, #{cursor_rec.sql_text if cursor_rec}"
        else   # Mutex etc.
          # P1 = “idn” = Unique Mutex Identifier. Hash value of library cache object protected by mutex or hash bucket number.
          # P2 = “value” = “Blocking SID | Shared refs” = Top 2 (4 on 64bit) bytes contain SID of blocker. This session is currently holding the mutex exclusively or modifying it. Lower bytes represent the number of shared references when the mutex is in-flux
          # P3 = “where” = “Location ID | Sleeps” = Top 2(4) bytes contain location in code (internal identifier) where mutex is being waited for. Lower bytes contain the number of sleeps for this mutex. These bytes not populated on some platforms, including Linux
          lc_obj_name = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ Type||' '||Owner||'.'||Name FROM gv$DB_Object_Cache WHERE Inst_ID=? AND Hash_Value=?", instance, p1.to_i]
          "Object=#{lc_obj_name}, Blocking-SID=#{ p2.to_i/2**(4*wordsize)}, number of shared references=#{p2.to_i%2**(4*wordsize)}, Location-ID=#{p3.to_i/2**(4*wordsize)}, Number of Sleeps=#{p3.to_i%2**(4*wordsize)} "
        end
      when event.match('library cache') && p1text=="handle address" then
        result = sql_select_one ["SELECT 'handle_address: Owner='''||kglnaown||''', Object='''||kglnaobj||'''' FROM x$kglob WHERE kglhdadr=HEXToRaw(TRIM(TO_char(?,'XXXXXXXXXXXXXXXX')))", p1]
        result = "Nothing found in x$kglob for p1" unless result
        result
      else
        "[kein Objekt zu ermitteln für diese Deutung p1, p2]"
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

end