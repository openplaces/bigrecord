require File.dirname(__FILE__) + '/../column_descriptor'
require File.dirname(__FILE__) + '/../exceptions'
require File.dirname(__FILE__) + '/../bigrecord_server'

module BigRecordDriver
class CassandraServer < BigRecordServer
  include_class "org.apache.cassandra.service.Cassandra"
  include_class "org.apache.cassandra.service.InvalidRequestException"
  include_class "org.apache.cassandra.service.NotFoundException"
  include_class "org.apache.cassandra.service.UnavailableException"
  include_class "org.apache.cassandra.service.column_t"
  include_class "org.apache.thrift.TException"
  include_class "org.apache.thrift.protocol.TBinaryProtocol"
  include_class "org.apache.thrift.transport.TSocket"
  include_class "org.apache.thrift.transport.TTransport"

  def configure(config = {})
    config[:adr]        ||= 'localhost'
    config[:port]       ||= 9160
    @config = config
    init_connection
  end
  
  def update(table_name, row, values, timestamp=nil)
    safe_exec do
      return nil unless row
      timestamp = 0 unless timestamp
      values.each do |column, value|  
      @cassandraClient.insert(table_name.to_s, row, column, value.to_bytes, timestamp, true)
      end
      row
    end
  end

  def get(table_name, row, column, options={})
    safe_exec do
      return nil unless row
      # Retreive only the last version by default
      options[:num_versions] ||= 1

      # validate the arguments
      raise ArgumentError, "num_versions must be >= 1" unless options[:num_versions] >= 1
      begin
        if options[:timestamp]
          raw_data = @cassandraClient.get_columns_since(table_name.to_s, row, column, options[:timestamp])
        else
          raw_data = @cassandraClient.get_column(table_name.to_s, row, column)
        end
      rescue NotFoundException => e2
        puts e2.message
        puts e2.class
      end
      # Return either a single value or an array, depending on the number of version that have been requested
      if options[:timestamp]
        return [] unless raw_data
        max_index = raw_data.length > options[:num_versions] || raw_data.length
        0..max_index.each do |i|
          arr[i] = Java::String.new(raw_data[i].value).to_s
        end
        arr
      else
        return nil unless raw_data
        Java::String.new(raw_data.value).to_s
      end
    end
  end

  def get_columns(table_name, row, columns, options={})
    safe_exec do
      return nil unless row
      raise ArgumentError, "timestamp on get_columns is not currently supported with cassandra" if options[:timestamp]
      arr = []
      columns.each_with_index do |col, i|
        begin
          if col[-1,1] == ':'
            arr + @cassandraClient.get_slice(table_name.to_s, row, col, -1, -1).to_a
          else
            arr + @cassandraClient.get_column(table_name.to_s, row, col)
          end
        rescue NotFoundException => e2
          puts e2.message
          puts e2.class
        end
      end
      unless !result or result.isEmpty
        values = {}
        arr.each do |column_t|
          values[column_t.getColumnName.to_s] = Java::String.new(column_t.value).to_s
        end
        values["attribute:id"] = row
        values
      end
      
    end
  end

## It's currently impossible to have compliant delete with cassandra,
## you would have to do it famiyl by family
#  def delete(table_name, row)
#    safe_exec do
#      table.remove(table_name, row, ??, ??, true)
#    end
#  end

  def ping
    safe_exec do
      @socket.isOpen
    end
  end

  def table_names
    safe_exec do
      @cassandraClient.getStringListProperty("tables") #.collect{|td| Java::String.new(td.getName).to_s}
    end
  end

  def table_exists?(table_name)
    !@cassandraClient.describeTable(table_name.to_s).include?("not found.")
  end

  private
    def init_connection
      @socket = TSocket.new(@config[:adr], @config[:port]);
      binary_protocol = TBinaryProtocol.new(@socket, false, false);
      @cassandraClient = Cassandra::Client.new(binary_protocol);
      @socket.open;
    end
end
end

port = ARGV[0]
port ||= 45000
DRb.start_service("druby://:#{port}", BigRecordDriver::CassandraServer.new)
puts "Started drb server on port #{port}."
DRb.thread.join
