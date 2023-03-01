# encoding: utf-8

require 'encryption'

# Hilfsmethoden mit Bezug auf die aktuell verbundene Datenbank sowie verbundene Einstellunen wie Sprache
module DatabaseHelper

public

  # Format für JQuery-UI Plugin DateTimePicker
  def timepicker_dateformat
    case get_locale
      when "de" then "dd.mm.yy"
      when "en" then "yy-mm-dd"
      else "dd.mm.yy"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Tag
  def strftime_format_with_days
    case get_locale
      when "de" then "%d.%m.%Y"
      when "en" then "%Y\u2011%m\u2011%d".encode('utf-8')                       # use unbreakable hyphen instead of '-'
      else "%d.%m.%Y"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden
  def strftime_format_with_seconds
    case get_locale
      when "de" then "%d.%m.%Y %H:%M:%S"
      when "en" then "%Y\u2011%m\u2011%d %H:%M:%S".encode('utf-8')              # use unbreakable hyphen instead of '-'
      else "%d.%m.%Y %H:%M:%S"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden-bruchteile
def strftime_format_with_fractions3
  case get_locale
  when "de" then "%d.%m.%Y %H:%M:%S.%3N"
  when "en" then "%Y\u2011%m\u2011%d %H:%M:%S.%3N".encode('utf-8')            # use unbreakable hyphen instead of '-'
  else "%d.%m.%Y %H:%M:%S.%3N"
  end
end

  # Maske für Date/Time-Konvertierung per strftime bis auf sekunden-bruchteile
  def strftime_format_with_fractions6
    case get_locale
    when "de" then "%d.%m.%Y %H:%M:%S.%6N"
    when "en" then "%Y\u2011%m\u2011%d %H:%M:%S.%6N".encode('utf-8')            # use unbreakable hyphen instead of '-'
    else "%d.%m.%Y %H:%M:%S.%6N"
    end
  end

  # Maske für Date/Time-Konvertierung per strftime bis auf Minuten
  def strftime_format_with_minutes
    case get_locale
      when "de" then "%d.%m.%Y %H:%M"
      when "en" then "%Y\u2011%m\u2011%d %H:%M".encode('utf-8')                 # use unbreakable hyphen instead of '-'
      else "%d.%m.%Y %H:%M"     # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_second_mask
    case get_locale
      when "de" then "DD.MM.YYYY HH24:MI:SS"
      when "en" then "YYYY-MM-DD HH24:MI:SS"
      else "DD.MM.YYYY HH24:MI:SS" # Deutsche Variante als default
    end
  end

  # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_minute_mask
    case get_locale
      when "de" then "DD.MM.YYYY HH24:MI"
      when "en" then "YYYY-MM-DD HH24:MI"
      else "DD.MM.YYYY HH24:MI" # Deutsche Variante als default
    end
  end

    # Ersetzung in TO_CHAR / TO_DATE in SQL
  def sql_datetime_date_mask
    case get_locale
      when "de" then "DD.MM.YYYY"
      when "en" then "YYYY-MM-DD"
      else "DD.MM.YYYY" # Deutsche Variante als default
    end
  end

  # Entscheiden auf Grund der Länge der Eingabe, welche Maske hier zu verwenden ist
  def sql_datetime_mask(datetime_string)
    return "sql_datetime_mask: Parameter=nil" if datetime_string.nil?           # Maske nicht verwendbar
    datetime_string.strip!                                                      # remove leading and trailing blanks
    case datetime_string.length
      when 10 then sql_datetime_date_mask
      when 16 then sql_datetime_minute_mask
      when 19 then sql_datetime_second_mask
      else
        raise "sql_datetime_mask: No SQL datetime mask found for '#{datetime_string}'"
    end

  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_minute_mask
    case get_locale
      when "de" then "TT.MM.JJJJ HH:MI"
      when "en" then "YYYY-MM-DD HH:MI"
      else "TT.MM.JJJJ HH:MI" # Deutsche Variante als default
    end
  end

  # Menschenlesbare Ausgabe in Hints etc
  def human_datetime_day_mask
    case get_locale
      when "de" then "TT.MM.JJJJ"
      when "en" then "YYYY-MM-DD"
      else "TT.MM.JJJJ" # Deutsche Variante als default
    end
  end


  def numeric_thousands_separator
    case get_locale
      when "de" then "."
      when "en" then ","
      else "." # Deutsche Variante als default
    end
  end


  def numeric_decimal_separator
    case get_locale
      when "de" then ","
      when "en" then "."
      else "," # Deutsche Variante als default
    end
  end

  def format_sql(sql_text, window_width)
    return nil if sql_text.nil?
    return sql_text if sql_text["\n"] || sql_text.length < 100                  # SQL is already linefeed-formatted or too small

    sql = sql_text.clone

    # Line feed at keywords
    pos = 0
    while pos < sql.length
      cmp_str = sql[pos, 25].upcase                                             # Compare sql beginning at pos, next 25 chars

      [                                                                         # Process array with searches and stepwidth
          [ '\(SELECT\s'              , 6],
          [ '\s+SELECT\s'             , 6],
          [ '\s+FROM\s'               , 5],
          [ '\s+LEFT +OUTER +JOIN\s'  , 15],
          [ '\s+LEFT +JOIN\s'         , 9],
          [ '\s+RIGHT +OUTER +JOIN\s' , 16],
          [ '\s+RIGHT +JOIN\s'        , 10],
          [ '\s+INNER +JOIN\s'        , 10],
          [ '\s+FULL +OUTER +JOIN\s'  , 15],
          [ '\s+CROSS +JOIN\s'        , 10],
          [ '\s+JOIN\s'               , 4],
          [ '\s+WHERE\s'              , 5],
          [ '\s+GROUP\s+BY'           , 8],
          [ '\s+ORDER\s+BY'           , 8],
          [ '\s+CASE\s+'              , 4],
          [ '\s+WHEN\s+'              , 4],
          [ '\s+ELSE\s+'              , 4],
          [ '\s+UNION\s+'             , 5],
          [ '\)UNION\s+'             , 5],
      ].each do |c|
        if cmp_str.match("^#{c[0]}")
          sql.insert(pos+1, "\n")
          pos += c[1]
        end
      end
      pos+=1                                                                    # Compare next char
    end

    # Hierarchy-depth

    pos         = 0
    comment     = false
    depth       = 0
    with_active = false
    with_started= false
    max_line_length = window_width.to_i / 15                                # Check maximum line length
    max_line_length = 80 if max_line_length.nil? || max_line_length == 0

    while pos < sql.length

      comment = true  if sql[pos, 2] == '/*'
      comment = false if sql[pos, 2] == '*/'

      unless comment
        if sql[pos] == '('
          depth += 1
        end
        if sql[pos] == ')'
          depth -= 1
        end
      end

      if with_active && with_started && depth == 0                              # end / switch to next with block
        next_new_line_pos = sql.index("\n", pos)                                # Position of next newline
        lf_pos = sql.index(/[,]/, pos)                                          # look for next comma
        if !lf_pos.nil? && sql[lf_pos+1] != "\n" &&                             # next comma not followed by newline
            (next_new_line_pos.nil? || lf_pos < next_new_line_pos)              # comma before next newline
          sql.insert(lf_pos+1, "\n")
          while sql[lf_pos+2] == ' ' do                                         # remove leading blanks from new line
            sql.slice!(lf_pos+2)
          end
          with_started = false                                                  # only one linefeed per WITH-select
        end
      end

      if pos == 0 || sql[pos-1] == "\n"                                         # New line indent
        cmp_str = sql[pos, sql.length-pos].upcase                               # Compare sql beginning at pos

        with_active = true  if cmp_str.index("WITH\s"  ) == 0                   # WITH-block active
        with_active = false if cmp_str.index("SELECT\s") == 0 && depth == 0     # First SELECT after WITH at base depth ends WITH-Block
        with_started = true if with_active && depth > 0                         # mark start of first with block

        # Wrap line at AND
        next_new_line_pos = cmp_str.index("\n")
        if (next_new_line_pos && next_new_line_pos > max_line_length) || ( next_new_line_pos.nil? && cmp_str.length >= max_line_length )
          rev_str = cmp_str[0, max_line_length].reverse
          lf_pos = rev_str.index(/\sDNA\s/)                                   # Look for last AND before max_line_length
          if lf_pos.nil? # Comma not found before max_new_line_pos
            lf_pos = cmp_str.index(/\sAND\s/, max_line_length) # look for next comma after max_line_length
            if !lf_pos.nil? && (next_new_line_pos.nil? || lf_pos < next_new_line_pos)
              sql.insert(pos + lf_pos + 1, "\n")
              cmp_str = sql[pos, sql.length - pos].upcase # Refresh Compare sql beginning at pos for next comparison
            end
          else # AND found before max_new_line_pos
            sql.insert(pos + max_line_length - lf_pos - 4, "\n")
            cmp_str = sql[pos, sql.length - pos].upcase # Refresh Compare sql beginning at pos for next comparison
          end
        end

        # Wrap line at maximum length
        next_new_line_pos = cmp_str.index("\n")
        if (next_new_line_pos && next_new_line_pos > max_line_length) || ( next_new_line_pos.nil? && cmp_str.length >= max_line_length )
          rev_str = cmp_str[0, max_line_length].reverse
          lf_pos = rev_str.index(/[,]/)                                       # Look for last comma before max_line_length
          if !lf_pos.nil? && lf_pos < max_line_length                         # Comma found before max_new_line_pos, but not on current pos
            sql.insert(pos+max_line_length-lf_pos, "\n")
            while sql[pos+max_line_length-lf_pos+1] == ' ' do                 # remove leading blanks from new line
              sql.slice!(pos+max_line_length-lf_pos+1)
            end
          else                                                                # Comma not found before max_new_line_pos
            lf_pos = cmp_str.index(/[,]/, max_line_length)                    # look for next comma after max_line_length
            if !lf_pos.nil? && lf_pos > 0 && (next_new_line_pos.nil? || lf_pos < next_new_line_pos) # next comma foubd, but nor in current pos
              sql.insert(pos+lf_pos, "\n")
              while sql[pos+lf_pos+1] == ' ' do                               # remove leading blanks from new line
                sql.slice!(pos+lf_pos+1)
              end
            end
          end
        end


        # indent normal content
        if  cmp_str.index("SELECT\s") != 0 &&
            cmp_str.index("FROM\s"  ) != 0 &&
            cmp_str.index("JOIN\s"  ) != 0 &&
            cmp_str.index("UNION\s" ) != 0 &&
            cmp_str.index("LEFT\s"  ) != 0 &&
            cmp_str.index("OUTER\s" ) != 0 &&
            cmp_str.index("WHERE\s" ) != 0 &&
            cmp_str.index("WITH\s"  ) != 0 &&
            cmp_str.index("GROUP\s" ) != 0 &&
            cmp_str.index("ORDER\s" ) != 0 &&
            !(with_active && depth == 0)
          sql.insert(pos, '    ')
          pos += 4
        end

        # Indent hierarchy
        depth.downto(1) do
          sql.insert(pos, '    ')
          pos += 4
        end
      end

      pos+=1                                                                    # Compare next char
    end




    "/* single line SQL-text formatted by Panorama */\n#{sql}"
  end

  def system_userid_subselect
    if get_db_version >= '12.1'
      "SELECT /*+ NO_MERGE */ User_ID FROM All_Users WHERE Oracle_Maintained = 'Y'"
    else
      "SELECT /*+ NO_MERGE */ User_ID FROM All_Users WHERE UserName IN ('AFARIA', 'APPQOSSYS', 'AUDSYS', 'CTXSYS', 'DMSYS', 'DBMSXSTATS', 'DBSNMP', 'EXFSYS', 'FLAGENT',
'MDSYS', 'OLAPSYS', 'ORDSYS', 'OUTLN', 'PATCH', 'PERFSTAT',
'SYS', 'SYSBACKUP', 'SYSDG', 'SYSKM', 'SYSMAN', 'SYSTEM', 'TSMSYS', 'WMSYS', 'XDB') "
    end

  end

  def system_schema_subselect
    if get_db_version >= '12.1'
      "SELECT /*+ NO_MERGE */ UserName FROM All_Users WHERE Oracle_Maintained = 'Y'"
    else
      " 'AFARIA', 'APPQOSSYS', 'AUDSYS', 'CTXSYS', 'DMSYS', 'DBMSXSTATS', 'DBSNMP', 'EXFSYS', 'FLAGENT',
'MDSYS', 'OLAPSYS', 'ORDSYS', 'OUTLN', 'PATCH', 'PERFSTAT',
'SYS', 'SYSBACKUP', 'SYSDG', 'SYSKM', 'SYSMAN', 'SYSTEM', 'TSMSYS', 'WMSYS', 'XDB' "
    end
  end

end