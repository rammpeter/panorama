module Panorama
  VERSION = "2.0.9"
  RELEASE_DATE = Date.parse('2014-10-03')

  RELEASE_DAY   = "%02d" % RELEASE_DATE.day
  RELEASE_MONTH = "%02d" % RELEASE_DATE.month
  RELEASE_YEAR  = "%04d" % RELEASE_DATE.year
end