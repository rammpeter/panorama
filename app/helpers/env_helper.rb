# encoding: utf-8
module EnvHelper
  #require "Encryptor"

  # Einlesen last_logins aus cookie-store
  def read_last_login_cookies
    begin
      if cookies[:last_logins]
        cookies_last_logins = Marshal.load(Encryptor.decrypt(cookies[:last_logins],  :key => Panorama::Application.config.secret_key_base))
      else
        cookies_last_logins = []
      end
    rescue Exception
      cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
    end
    cookies_last_logins = [] unless cookies_last_logins.instance_of?(Array)  # Falscher Typ des Cookies?
    cookies_last_logins
  end

  # Zurückschreiben des Cookies in cookie-store
  def write_last_login_cookies(cookies_last_logins)
    cookies.permanent[:last_logins] =  Encryptor.encrypt(Marshal.dump(cookies_last_logins), :key => Panorama::Application.config.secret_key_base)           # Zurückschreiben des Cookies
  end


end