BRD_ROOT = File.dirname(__FILE__)

require BRD_ROOT + '/big_record_driver/client'
require BRD_ROOT + '/big_record_driver/exceptions'
require BRD_ROOT + '/big_record_driver/column_descriptor'
require BRD_ROOT + '/big_record_driver/version'

module BigRecord
  module Driver
  end
end

# Aliasing the old namespace
BigRecordDriver = BigRecord::Driver
