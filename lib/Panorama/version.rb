module Panorama
  VERSION = "2.0.32"
  RELEASE_DATE = Date.parse('2015-01-22')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end
