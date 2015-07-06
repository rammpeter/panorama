# encoding: utf-8

module AdditionHelper


  # in welchem Schema liegt Tabelle und wie heißt sie
  def object_increase_object_name
    schemas = sql_select_all "SELECT Owner, Table_Name FROM All_Tables WHERE Table_Name='OG_SEG_SPACE_IN_TBS'"
    raise "Tabelle OG_SEG_SPACE_IN_TBS findet sich in mehreren Schemata: erwartet wird genau ein Schema mit dieser Tabelle! #{schemas}" if schemas.count > 1
    return "#{schemas[0].owner}.#{schemas[0].table_name}" if schemas.count == 1

    schemas = sql_select_all "SELECT Owner, View_Name FROM All_Views WHERE View_Name='UT_SEG_SPACE_IN_TBS_V'"
    raise "View UT_SEG_SPACE_IN_TBS_V findet sich in mehreren Schemata: erwartet wird genau ein Schema mit diesem View! #{schemas}" if schemas.count > 1
    return "#{schemas[0].owner}.#{schemas[0].view_name}" if schemas.count == 1

    raise "Tabelle OG_SEG_SPACE_IN_TBS oder View UT_SEG_SPACE_IN_TBS_V in keinem Schema der DB gefunden" if schemas.count == 0
  end

end

