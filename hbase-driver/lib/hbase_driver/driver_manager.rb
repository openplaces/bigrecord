module Hbase
  class DriverManager
    CMD = File.dirname(__FILE__) + '/../../bin/hbase-driver'

    class << self
      def start(port = 40000)
        `ruby #{CMD} start -p #{port.to_s}`
      end
      
      def restart(port = 40000)
        `ruby #{CMD} restart -p #{port.to_s}`
      end
  
      def stop(port = 40000)
        `ruby #{CMD} stop -p #{port.to_s}`
      end
      
      def running?(port = 40000)
        status = `ruby #{CMD} status -p #{port.to_s}`
        status == "Running.\n"
      end
      
      def silent_start(port = 40000)
        start(port) unless running?(port)
      end
    end
    
  end
end
