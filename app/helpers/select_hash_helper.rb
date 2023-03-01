# encoding: utf-8
# Erweiterung der Klasse Hash um Zugriff auf Inhalte per Methode
module SelectHashHelper

  # Ermittelns Spaltenwert aus korrespondierendem Hash-Value, Parameter wird als String erwartet
  def get_hash_value(key_value)
    raise "SelectHashHelper.get_hash_value: class should be of Hash but is #{self.class.name}, called with parameter #{key_value.inspect}" unless self.is_a? Hash
    if has_key?(key_value)
      self[key_value]
    else
      if has_key?(key_value.to_sym)
        self[key_value.to_sym]
      else
        raise "column '#{key_value}' does not exist in result-Hash with key-class 'String' or 'Symbol'"
      end
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