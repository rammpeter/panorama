class Domain < ActiveRecord::Base
  self.table_name =  "SYSP.DOMAIN"
  #attr_accessible :name
  has_many :ofmessagetype, :foreign_key => "id_domain"

  # Request-übergreifendes Caching des Models, optional :expires_in => 1.minutes
  def self.get_cached_instance(id)
    Rails.cache.fetch("Domain", :expires_in => 100.minute) {   # Komplette Tabelle als cache führen
      cache_entry = {}
      self.all.each do |m|
        cache_entry[m.id] = m
      end
      cache_entry
    }[id]

  end


end
