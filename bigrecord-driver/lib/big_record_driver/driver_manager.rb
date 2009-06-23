module BigRecordDriver

  class DriverManager
    class << self

      def set_cmd(db = 'hbase')
        @@CMD = File.dirname(__FILE__) + "/../../bin/#{db}-driver"
      end
      DriverManager.set_cmd
      def start(port = 40005)
        `ruby #{@@CMD} start -p #{port.to_s}`
      end

      def restart(port = 40005)
        `ruby #{@@CMD} restart -p #{port.to_s}`
      end

      def stop(port = 40005)
        `ruby #{@@CMD} stop -p #{port.to_s}`
      end

      def running?(port = 40005)
        status = `ruby #{@@CMD} status -p #{port.to_s}`
        status == "Running.\n"
      end

      def silent_start(port = 40005)
        start(port) unless running?(port)
      end
    end

  end

end
