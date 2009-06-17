require File.dirname(__FILE__) + '/../column_descriptor'
require File.dirname(__FILE__) + '/../exceptions'
require File.dirname(__FILE__) + '/../bigrecord_server'

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
      column = @cassandraClient.get_column(table_name.to_s, row, column)
      Java::String.new(column.value).to_s
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

port = ARGV[0]
port ||= 45000
DRb.start_service("druby://:#{port}", CassandraServer.new)
puts "Started drb server on port #{port}."
DRb.thread.join
