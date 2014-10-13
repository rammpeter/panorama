# encoding: utf-8
# Wird von application_helper der Panorama-Engine inkludiert, dient zum überschreibrn / erweitertern durch Duplikat des Files in Nutzern der Engine

module ExplainApplicationInfoHelper
  protected
  # Application-Spezifisch: Extrahieren weiterer Info aus Kurzbezeichnern
  # Return Hash mit zwei Elementen:  :short_info  :long_info
  def explain_application_info(org_text)
    return {}

    # Example:
    # retval = {}
    # retval[:short_info] = ws.name
    # retval[:long_info]  = "#{ws.name}"
    # return retval
  end


end