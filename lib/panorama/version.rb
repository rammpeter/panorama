require 'date' 

module Panorama
  # VERSION and REL EASE_DATE should have fix syntax and positions because they are parsed from other sites
  VERSION = '2.17.01'
  RELEASE_DATE = Date.parse('2023-03-14')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end


