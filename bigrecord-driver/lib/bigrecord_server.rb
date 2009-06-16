# The name of the java String class conflicts with ruby's String class.
module Java
  include_class "java.lang.String"
  include_class "java.lang.Exception"
end

class String
  def to_bytes
    Java::String.new(self).getBytes
  end
end
class BigRecordServer
  def configure(config = {})
    raise NotImplementedError 
  end
  
  def update(table_name, row, values, timestamp=nil)
    raise NotImplementedError
  end

  def get(table_name, row, column, options={})
    raise NotImplementedError
  end

  def get_columns(table_name, row, columns, options={})
    raise NotImplementedError
  end

  def get_consecutive_rows(table_name, start_row, limit, columns, stop_row = nil)
    raise NotImplementedError
  end

  def delete(table_name, row)
    raise NotImplementedError
  end

  def create_table(table_name, column_descriptors)
    raise NotImplementedError
  end

  def drop_table(table_name)
    raise NotImplementedError
  end

  def truncate_table(table_name)
    raise NotImplementedError
  end

  def ping
    raise NotImplementedError
  end

  def table_exists?(table_name)
    raise NotImplementedError
  end

  def table_names
    raise NotImplementedError
  end

  def method_missing(method, *args)
    super
  rescue NoMethodError
    raise NoMethodError, "undefined method `#{method}' for \"#{self}\":#{self.class}"
  end

  def respond_to?(method)
    super
  end
end
