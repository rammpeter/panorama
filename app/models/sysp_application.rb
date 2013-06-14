# Der Klassenname Application ist leider bereits anderweitig vergeben, so dass zu diesem Namen geriffen wurde
class SyspApplication < ActiveRecord::Base
  self.table_name =  "sysp.application"
  #belongs_to :developmentteam, :foreign_key => "id_developmentteam"


  # Request-übergreifendes Caching des Models
  def self.get_cached_instance(id)
    Rails.cache.fetch("SyspApplication_#{id}") { self.find(id) }
  end


  # ersatz fuer belongs_to
  def developmentteam
    Developmentteam.get_cached_instance(id_developmentteam)
  end
end
