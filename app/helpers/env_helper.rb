# encoding: utf-8
module EnvHelper

  # Einlesen last_logins aus cookie-store
  def read_last_login_cookies
    begin
      if cookies[:last_logins]
        crypt = ActiveSupport::MessageEncryptor.new(Panorama::Application.config.secret_key_base)
        cookies_last_logins = crypt.decrypt_and_verify(cookies[:last_logins])
      else
        cookies_last_logins = []
      end
#    rescue Exception
#      cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
    end
    cookies_last_logins = [] unless cookies_last_logins.instance_of?(Array)  # Falscher Typ des Cookies?

    # Vergabe des neuen Feldes ID für alte Cookies, die noch keine ID enthalten
    new_id = 0
    cookies_last_logins.each do |value|
      new_id = new_id + 1
      unless value[:id]
        value[:id] = new_id
        write_last_login_cookies(cookies_last_logins)                         # Persistieren der ID-Vergabe
      end
    end

    cookies_last_logins
  end

  # Zurückschreiben des Cookies in cookie-store
  def write_last_login_cookies(cookies_last_logins)

    crypt = ActiveSupport::MessageEncryptor.new(Panorama::Application.config.secret_key_base)
    cookies[:last_logins] = crypt.encrypt_and_sign(cookies_last_logins)
  end


end