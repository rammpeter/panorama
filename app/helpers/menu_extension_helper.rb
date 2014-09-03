# encoding: utf-8
# Wird von MenuHelper inkludiert, kann in App Engine überschrieben werden

module MenuExtensionHelper
  def extend_main_menu main_menu  # Methode kann in App fuer Erweiterung des Menüs überschrieben werden
    main_menu
  end
end