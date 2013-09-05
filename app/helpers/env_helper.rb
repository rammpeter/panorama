# encoding: utf-8
module EnvHelper

  # Base64-Verschlüsselung ist ein shortCut für Rails3, um die Abhängigkeit von JCE Java Cryptographic Extension zu umgehen
  # Alternative: http://crypt.rubyforge.org

  # Einlesen last_logins aus cookie-store
  def read_last_login_cookies
    begin
      if cookies[:last_logins]
        cookies_last_logins = Marshal.load(Base64::decode64(cookies[:last_logins]))
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
    cookies.permanent[:last_logins] =  Base64::encode64(Marshal.dump(cookies_last_logins))           # Zurückschreiben des Cookies
  end


end