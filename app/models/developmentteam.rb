class Developmentteam < ActiveRecord::Base
  self.table_name =  "sysp.developmentteam"
  has_many :application, :foreign_key => "id_developmentteam"

  def self.get_cached_instance(id)
    Rails.cache.fetch("Developmentteam_#{id}") { self.find(id) }
  end

  def selectlist_entry
    id.to_s + ":"+name
  end
end

