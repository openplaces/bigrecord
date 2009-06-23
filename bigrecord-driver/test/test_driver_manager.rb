$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'big_record_driver'

class TestDriverManager < Test::Unit::TestCase

  # everything is in a sequence and therefore there's only 1 test
  def test_all
    port = 40000
  
    # stop the driver if it's already running
    assert_nothing_raised do
      BigRecordDriver::DriverManager.stop(port) if BigRecordDriver::DriverManager.running?(port)
    end
    assert !BigRecordDriver::DriverManager.running?(port), "The driver is already running and it couldn't be stopped"

    # start the real tests
    assert_nothing_raised do
      BigRecordDriver::DriverManager.start(port)
    end
    assert BigRecordDriver::DriverManager.running?(port), "The driver couldn't be started"
    
    assert_nothing_raised do
      BigRecordDriver::DriverManager.restart(port)
    end
    assert BigRecordDriver::DriverManager.running?(port), "The driver couldn't be restarted"
    
    assert_nothing_raised("The driver should be able to do a silent start when it's already running") do
      BigRecordDriver::DriverManager.silent_start(port)
    end
    assert BigRecordDriver::DriverManager.running?(port), "The driver stopped during a silent start instead of staying alive"

    assert_nothing_raised do
      BigRecordDriver::DriverManager.stop(port)
    end
    assert !BigRecordDriver::DriverManager.running?(port), "The driver couldn't be stopped"
    
    assert_nothing_raised("The driver should be able to do a silent start when it's not running") do
      BigRecordDriver::DriverManager.silent_start(port)
    end
    assert BigRecordDriver::DriverManager.running?(port), "The driver couldn't be started silently"

  end
  
end
