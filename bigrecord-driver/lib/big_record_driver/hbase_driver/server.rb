require File.dirname(__FILE__) + '/../column_descriptor'
require File.dirname(__FILE__) + '/../exceptions'
require File.dirname(__FILE__) + '/../bigrecord_server'

module BigRecordDriver

class HbaseServer < BigRecordServer
  include_class "java.util.TreeMap"

  include_class "org.apache.hadoop.hbase.client.HTable"
  include_class "org.apache.hadoop.hbase.client.HBaseAdmin"
  include_class "org.apache.hadoop.hbase.io.BatchUpdate"
  include_class "org.apache.hadoop.hbase.HBaseConfiguration"
  include_class "org.apache.hadoop.hbase.HConstants"
  include_class "org.apache.hadoop.hbase.HStoreKey"
  include_class "org.apache.hadoop.hbase.HTableDescriptor"
  include_class "org.apache.hadoop.hbase.HColumnDescriptor"

  include_class "org.apache.hadoop.io.Writable"

  # Establish the connection with HBase with the given configuration parameters.
  def configure(config = {})
    config[:quorum]        ||= 'localhost'
    config[:zk_client_port]  ||= '2181'

    @config = config

    init_connection
  end

  # Atomic row insertion/update. Example:
  #   update('entities', 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8', {'attribute:name' => "--- Oahu\n",
  #                                                               'attribute:travel_rank' => "--- 0.90124565\n"})
  #   => 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8'
  def update(table_name, row, values, timestamp=nil)
    safe_exec do
      return nil unless row
      table = connect_table(table_name)

      batch = timestamp ? BatchUpdate.new(row, timestamp) : BatchUpdate.new(row)

      values.each do |column, value|
        batch.put(column, value.to_bytes)
      end

      table.commit(batch)
      row
    end
  end

  # Returns a column of a row. Example:
  #   get('entities', 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8', 'attribute:travel_rank')
  #   => "--- 0.90124565\n"
  #
  # valid options:
  #   :timestamp      => integer corresponding to the time when the record was saved in hbase
  #   :versions   => number of versions to retreive, starting at the specified timestamp (or the latest)
  def get(table_name, row, column, options={})
    safe_exec do
      return nil unless row
      table = connect_table(table_name)

      # Retreive only the last version by default
      options[:versions] ||= options[:num_versions]
      options[:versions] ||= 1

      # validate the arguments
      raise ArgumentError, "versions must be >= 1" unless options[:versions] >= 1

      # get the raw data from hbase
      unless options[:timestamp]
        if options[:versions] == 1
          raw_data = table.get(row, column)
        else
          raw_data = table.get(row,
                                column,
                                options[:versions])
        end
      else
        raw_data = table.get(row,
                              column,
                              options[:timestamp],
                              options[:versions])
      end

      # Return either a single value or an array, depending on the number of version that have been requested
      if options[:versions] == 1
        return nil unless raw_data
        raw_data = raw_data[0] if options[:timestamp]
        to_ruby_string(raw_data)
      else
        return [] unless raw_data
        raw_data.collect do |raw_data_version|
          to_ruby_string(raw_data_version)
        end
      end
    end
  end

  # Returns the last version of the given columns of the given row. The columns works with
  # regular expressions (e.g. 'attribute:' matches all attributes columns). Example:
  #   get_columns('entities', 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8', ['attribute:'])
  #   => {"attribute:name" => "--- Oahu\n", "attribute:travel_rank" => "--- 0.90124565\n", etc...}
  def get_columns(table_name, row, columns, options={})
    safe_exec do
      return nil unless row
      table_name = table_name.to_s
      table = connect_table(table_name)

      java_cols = Java::String[columns.size].new
      columns.each_with_index do |col, i|
        java_cols[i] = Java::String.new(col)
      end

      result =
      if options[:timestamp]
        table.getRow(row, java_cols, options[:timestamp])
      else
        table.getRow(row, java_cols)
      end

      unless !result or result.isEmpty
        values = {}
        result.entrySet.each do |entry|
          column_name = Java::String.new(entry.getKey).to_s
          values[column_name] = to_ruby_string(entry.getValue)
        end
        values["id"] = row
        values
      else
        nil
      end
    end
  end

  # Get consecutive rows. Example to get 100 records starting with the one specified and get all the
  # columns in the column family 'attribute:' :
  #   get_consecutive_rows('entities', 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8', 100, ['attribute:'])
  def get_consecutive_rows(table_name, start_row, limit, columns, stop_row = nil)
    safe_exec do
      table_name = table_name.to_s
      table = connect_table(table_name)

      java_cols = Java::String[columns.size].new
      columns.each_with_index do |col, i|
        java_cols[i] = Java::String.new(col)
      end

      start_row ||= ""
      start_row = start_row.to_s

      # We cannot set stop_row like start_row because a
      # default stop row would have to be the biggest value possible
      if stop_row
        scanner = table.getScanner(java_cols, start_row, stop_row, HConstants::LATEST_TIMESTAMP)
      else
        scanner = table.getScanner(java_cols, start_row)
      end

      row_count = 0 if limit
      result = []
      while (row_result = scanner.next) != nil
        if limit
          break if row_count == limit
          row_count += 1
        end
        values = {}
        row_result.entrySet.each do |entry|
          column_name = Java::String.new(entry.getKey).to_s
          data = to_ruby_string(entry.getValue)
          values[column_name] = data
        end
        unless values.empty?
          # TODO: is this really supposed to be hard coded?
          values['id'] = Java::String.new(row_result.getRow).to_s
          result << values
        end
      end
      scanner.close
      result
    end
  end

  # Delete a whole row.
  def delete(table_name, row, timestamp)
    raise ArgumentError, "requires timestamp argument (pass current time to remove everything)" unless timestamp

    safe_exec do
      table = connect_table(table_name)
      timestamp ? table.deleteAll(row.to_bytes, timestamp) : table.deleteAll(row.to_bytes)
    end
  end

  # Create a table
  def create_table(table_name, column_descriptors)
    safe_exec do
      table_name = table_name.to_s
      unless table_exists?(table_name)
        tdesc = HTableDescriptor.new(table_name)

        column_descriptors.each do |cd|
          cdesc = generate_column_descriptor(cd)

          tdesc.addFamily(cdesc)
        end
        @admin.createTable(tdesc)
      else
        raise BigRecordDriver::TableAlreadyExists, table_name
      end
    end
  end

  # Delete a table
  def drop_table(table_name)
    safe_exec do
      table_name = table_name.to_s

      if @admin.tableExists(table_name)
        @admin.disableTable(table_name)
        @admin.deleteTable(table_name)

        # Remove the table connection from the cache
        @tables.delete(table_name) if @tables.has_key?(table_name)
      else
        raise BigRecordDriver::TableNotFound, table_name
      end
    end
  end

  def add_column(table_name, column_descriptor)
    safe_exec do
      table_name = table_name.to_s

      if @admin.tableExists(table_name)
        @admin.disableTable(table_name)

        cdesc = generate_column_descriptor(column_descriptor)
        @admin.addColumn(table_name, cdesc)

        @admin.enableTable(table_name)
      else
        raise BigRecordDriver::TableNotFound, table_name
      end
    end
  end

  def remove_column(table_name, column_name)
    safe_exec do
      table_name = table_name.to_s
      column_name = column_name.to_s

      if @admin.tableExists(table_name)
        @admin.disableTable(table_name)

        column_name << ":" unless column_name =~ /:$/
        @admin.deleteColumn(table_name, column_name)

        @admin.enableTable(table_name)
      else
        raise BigRecordDriver::TableNotFound, table_name
      end
    end
  end

  def modify_column(table_name, column_descriptor)
    safe_exec do
      table_name = table_name.to_s
      column_name = column_name.to_s

      if @admin.tableExists(table_name)
        @admin.disableTable(table_name)

        cdesc = generate_column_descriptor(column_descriptor)
        @admin.modifyColumn(table_name, column_descriptor.name, cdesc)

        @admin.enableTable(table_name)
      else
        raise BigRecordDriver::TableNotFound, table_name
      end
    end
  end

  def truncate_table(table_name)
    safe_exec do
      table_name = table_name.to_s
      table = connect_table(table_name)
      tableDescriptor = table.getTableDescriptor
      drop_table(table_name)
      @admin.createTable(tableDescriptor)
    end
  end

  def ping
    safe_exec do
      @admin.isMasterRunning
    end
  end

  def table_exists?(table_name)
    safe_exec do
      @admin.tableExists(table_name.to_s)
    end
  end

  def table_names
    safe_exec do
      @admin.listTables.collect{|td| Java::String.new(td.getName).to_s}
    end
  end

#  def const_missing(const)
#    super
#  rescue NameError => ex
#    raise NameError, "uninitialized constant #{const}"
#  end

private
  # Create a connection to a Hbase table and keep it in memory.
  def connect_table(table_name)
    safe_exec do
      table_name = table_name.to_s
      return @tables[table_name] if @tables.has_key?(table_name)

      if table_exists?(table_name)
        @tables[table_name] = HTable.new(@conf, table_name)
      else
        if table_name and !table_name.empty?
          raise BigRecordDriver::TableNotFound, table_name
        else
          raise ArgumentError, "Table name not specified"
        end
      end
      @tables[table_name]
    end
  end

  def init_connection
    safe_exec do
      @conf = HBaseConfiguration.new
      @conf.set('hbase.zookeeper.quorum', "#{@config[:quorum]}")
      @conf.set('hbase.zookeeper.property.clientPort', "#{@config[:zk_client_port]}")
      @admin = HBaseAdmin.new(@conf)
      @tables = {}
    end
  end

  def generate_column_descriptor(column_descriptor)
    raise ArgumentError, "a column descriptor is missing a name" unless column_descriptor.name
    raise "bloom_filter option not supported yet" if column_descriptor.bloom_filter

    if column_descriptor.compression
      compression =
      case column_descriptor.compression
        when :none;   HColumnDescriptor.CompressionType.NONE
        when :block;  HColumnDescriptor.CompressionType.BLOCK
        when :record; HColumnDescriptor.CompressionType.RECORD
        else
          raise ArgumentError, "Invalid compression type: #{column_descriptor.compression} for the column_family #{column_descriptor.name}"
      end
    end

    n_versions    = column_descriptor.versions
    in_memory     = column_descriptor.in_memory

    # set the default values of the missing parameters
    n_versions        ||= HColumnDescriptor::DEFAULT_VERSIONS
    compression       ||= HColumnDescriptor::DEFAULT_COMPRESSION
    in_memory         ||= HColumnDescriptor::DEFAULT_IN_MEMORY
    block_cache       ||= HColumnDescriptor::DEFAULT_BLOCKCACHE
    block_size        ||= HColumnDescriptor::DEFAULT_BLOCKSIZE
    bloomfilter       ||= HColumnDescriptor::DEFAULT_BLOOMFILTER
    ttl               ||= HColumnDescriptor::DEFAULT_TTL

    # add the ':' at the end if the user didn't specify it
    column_descriptor.name << ":" unless column_descriptor.name =~ /:$/

    cdesc = HColumnDescriptor.new(column_descriptor.name.to_bytes,
                                  n_versions,
                                  compression,
                                  in_memory,
                                  block_cache,
                                  block_size,
                                  ttl,
                                  bloomfilter)

    return cdesc
  end

end

end

port = ARGV[0]
port ||= 40000
DRb.start_service("druby://:#{port}", BigRecordDriver::HbaseServer.new)
puts "Started drb server on port #{port}."
DRb.thread.join
