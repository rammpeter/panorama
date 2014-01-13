# encoding: utf-8
module EnvHelper
  require "zlib"

  # Einlesen last_logins aus cookie-store
  def read_last_login_cookies
    begin
      if cookies[:last_logins]
        cookies_last_logins = Marshal.load(Zlib::Inflate.inflate(cookies[:last_logins]))
      else
        cookies_last_logins = []
      end
    rescue Exception
      cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
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

  # Zurückschreiben des Cookies in cookie-store, Komprimieren, um 4K-Limit nicht zu überschreiten
  def write_last_login_cookies(cookies_last_logins)
    compressed_cookie = Zlib::Deflate.deflate(Marshal.dump(cookies_last_logins))
    cookies[:last_logins] = { :value => compressed_cookie, :expires => 1.year.from_now }
  end


end