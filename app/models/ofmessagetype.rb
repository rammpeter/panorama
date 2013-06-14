class Ofmessagetype < ActiveRecord::Base
  self.table_name =  "SYSP.OFMESSAGETYPE"
  has_many :ofmessage, :foreign_key => "id_ofmessagetype"
  belongs_to :application,    :foreign_key => "id_application", :class_name => "SyspApplication"

  # Request-übergreifendes Caching des Models
  def self.get_cached_instance(id, database_hash)
    # Nicht länger als eine Minute cachen wegen Aktualität, separate Cache-Einträge je DB-Connection führen
    Rails.cache.fetch("Ofmessagetypes_#{database_hash}", :expires_in => 1.minute) {   # Komplette Tabelle als cache führen
      cache_entry = {}
      self.all.each do |m|
        cache_entry[m.id] = m
      end
      cache_entry
    }[id]
  end


  def domain
    Domain.get_cached_instance(self.id_domain)
  end


  def domains
    domain = Domain.get_cached_instance(self.id_domain)
    domain.name
  end
end
