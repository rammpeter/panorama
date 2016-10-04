# encoding: utf-8
# Erweiterung der Klasse Hash um Zugriff auf Inhalte per Methode
module SelectHashHelper

  # Ermittelns Spaltenwert aus korrespondierendem Hash-Value, Parameter wird als String erwartet
  def get_hash_value(key)
    if has_key?(key)
      self[key]
    else
      raise "column '#{key}' does not exist in result-Hash with key-class 'String' or 'Symbol'" unless has_key?(key.to_sym)
      self[key.to_sym]
    end
  end

  # Ermittelns Spaltenwert aus korrspondierendem Hash-Value
  def set_hash_value(key, value)
    self[key] = value
  end

  # Überschreiben der existierenden Methode "id" der Klasse Hash um Spalte "id" auszulesen
  def id
    get_hash_value 'id'
  end

  # Umlenken des Methoden-Aufrufes auf den Hash-Inhalt gleichen Namens
  def method_missing(sym, *args, &block)
    methodname = sym.to_s
    if methodname['=']                  # Setter angefragt
      set_hash_value methodname.delete('='), args[0]  # Hash-Wert erzeugen
    else                                # Getter angefragt
      get_hash_value methodname
    end
  end

end

# Toleriert Ansprache mit nicht existiernden Methoden und liefert nil zurück
module TolerantSelectHashHelper
  include SelectHashHelper

  # Überladen der Methode get_hash_value mit return nil statt Exception
  def get_hash_value(key)
    if has_key?(key)
      self[key]
    else
      self[key.to_sym]      # Liefert nil, wenn auch mit symbol kein Treffer
    end
  end


end