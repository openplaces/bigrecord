module BigDB
  class BigDBError < StandardError
  end
  class TableNotFound < BigDBError
  end
  class TableAlreadyExists < BigDBError
  end
  class JavaError < BigDBError
  end
  class ConnectionError < BigDBError
  end
end
