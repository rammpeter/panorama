# encoding: utf-8
# Wird von MenuHelper inkludiert, kann in App Engine überschrieben werden

module Panorama::MenuExtensionHelper
  def extend_main_menu main_menu  # Methode kann in App fuer Erweiterung des Menüs überschrieben werden
    main_menu
  end

  def contact_mail_addr
    'Peter@ramm-oberhermsdorf.de'
  end

end