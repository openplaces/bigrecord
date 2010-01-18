module BigRecord
  module Driver
    class DriverError < StandardError
    end
    class TableNotFound < DriverError
    end
    class TableAlreadyExists < DriverError
    end
    class JavaError < DriverError
    end
    class ConnectionError < DriverError
    end
  end
end
