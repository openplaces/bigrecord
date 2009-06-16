module Hbase
  class HbaseError < StandardError
  end
  class TableNotFound < HbaseError
  end
  class TableAlreadyExists < HbaseError
  end
  class JavaError < HbaseError
  end
  class ConnectionError < HbaseError
  end
end
