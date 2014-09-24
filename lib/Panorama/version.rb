module Panorama
  VERSION = "2.0.7"
  RELEASE_DATE = Date.parse('2014-09-24')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end
