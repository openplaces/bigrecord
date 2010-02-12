require File.dirname(__FILE__) + '/../column_descriptor'
require File.dirname(__FILE__) + '/../exceptions'
require File.dirname(__FILE__) + '/../server'

module BigRecord
  module Driver

    class HbaseServer < Server
      java_import "java.util.TreeMap"
      include_package "org.apache.hadoop.hbase.client"
      java_import "org.apache.hadoop.hbase.KeyValue"
      java_import "org.apache.hadoop.hbase.io.hfile.Compression"
      java_import "org.apache.hadoop.hbase.HBaseConfiguration"
      java_import "org.apache.hadoop.hbase.HTableDescriptor"
      java_import "org.apache.hadoop.hbase.HColumnDescriptor"

      # Establish the connection with HBase with the given configuration parameters.
      def configure(config = {})
        config[:zookeeper_quorum]       ||= 'localhost'
        config[:zookeeper_client_port]  ||= '2181'

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
          row_lock = table.lockRow(row.to_bytes)

          put = generate_put(row, values, timestamp, row_lock)
          table.put(put)

          table.unlockRow(row_lock)

          row
        end
      end

      # Returns a column of a row. Example:
      #   get('entities', 'b9cef848-a4e0-11dc-a7ba-0018f3137ea8', 'attribute:travel_rank')
      #   => "--- 0.90124565\n"
      #
      # valid options:
      #   :timestamp  => integer corresponding to the time when the record was saved in hbase
      #   :versions   => number of versions to retreive, starting at the specified timestamp (or the latest)
      def get(table_name, row, column, options={})
        safe_exec do
          return nil unless row

          table = connect_table(table_name)

          # Grab the version number if the client's using the old API,
          # or retrieve only the lastest version by default
          options[:versions] ||= options[:num_versions]
          options[:versions] ||= 1

          # validate the arguments
          raise ArgumentError, "versions must be >= 1" unless options[:versions] >= 1

          get = generate_get(row, column, options)
          result = table.get(get)

          if (result.nil? || result.isEmpty)
            return (options[:versions] == 1 ? nil : [])
          else
            output = result.list.collect do |keyvalue|
              to_ruby_string(keyvalue.getValue)
            end

            return (options[:versions] == 1 ? output[0] : output)
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

          get = generate_get(row, columns, options)
          result = table.get(get)

          begin
            parse_result(result)
          rescue
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

          scan = Scan.new
          scan.setStartRow(start_row.to_bytes) if start_row
          scan.setStopRow(stop_row.to_bytes) if stop_row

          columns.each do |column|
            (column[-1,1] == ":") ?
              scan.addFamily(column.gsub(":", "").to_bytes) :
              scan.addColumn(column.to_bytes)
          end

          scanner = table.getScanner(scan)

          if limit
            results = scanner.next(limit)
          else
            results = []
            while (row_result = scanner.next) != nil
              results << row_result
            end
          end

          output = []
          results.each do |result|
            output << parse_result(result)
          end
          scanner.close

          return output
        end
      end

      # Delete a whole row.
      def delete(table_name, row, timestamp = nil)
        safe_exec do
          table = connect_table(table_name)

          if timestamp
            row_lock = table.lockRow(row.to_bytes)
            table.delete(Delete.new(row.to_bytes, timestamp, row_lock))
            table.unlockRow(row_lock)
          else
            table.delete(Delete.new(row.to_bytes))
          end
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
            raise TableAlreadyExists, table_name
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
            raise TableNotFound, table_name
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
            raise TableNotFound, table_name
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
            raise TableNotFound, table_name
          end
        end
      end

      def modify_column(table_name, column_descriptor)
        safe_exec do
          table_name = table_name.to_s

          if @admin.tableExists(table_name)
            @admin.disableTable(table_name)

            cdesc = generate_column_descriptor(column_descriptor)
            @admin.modifyColumn(table_name, column_descriptor.name, cdesc)

            @admin.enableTable(table_name)
          else
            raise TableNotFound, table_name
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

    private

      def init_connection
        safe_exec do
          @conf = HBaseConfiguration.new
          @conf.set('hbase.zookeeper.quorum', "#{@config[:zookeeper_quorum]}")
          @conf.set('hbase.zookeeper.property.clientPort', "#{@config[:zookeeper_client_port]}")
          @admin = HBaseAdmin.new(@conf)
          @tables = {}
        end
      end

      # Create a connection to an HBase table and keep it in memory.
      def connect_table(table_name)
        safe_exec do
          table_name = table_name.to_s
          return @tables[table_name] if @tables.has_key?(table_name)

          if table_exists?(table_name)
            @tables[table_name] = HTable.new(@conf, table_name)
          else
            if table_name and !table_name.empty?
              raise TableNotFound, table_name
            else
              raise ArgumentError, "Table name not specified"
            end
          end
          @tables[table_name]
        end
      end

      # Create a Get object given parameters.
      #
      # @param [String] row
      # @param [Array, String] A single (or collection) of strings
      #     fully qualified column name or column family (ends with ':').
      # @param [Hash] options
      #
      # @return [Get] org.apache.hadoop.hbase.client.Get object
      #     corresponding to the arguments passed.
      def generate_get(row, columns, options = {})
        columns = [columns].flatten

        get = Get.new(row.to_bytes)

        columns.each do |column|
          # If the column name ends with ':' then it's a column family.
          (column[-1,1] == ":") ?
            get.addFamily(column.gsub(":", "").to_bytes) :
            get.addColumn(column.to_bytes)
        end

        get.setMaxVersions(options[:versions]) if options[:versions]

        # Need to add 1 to the timestamp due to the the API sillyness, i.e. min timestamp
        # is inclusive while max timestamp is exclusive.
        get.setTimeRange(java.lang.Long::MIN_VALUE, options[:timestamp]+1) if options[:timestamp]

        return get
      end

      # Create a Put object given parameters.
      #
      # @param [String] row
      # @param [Hash] Keys as the fully qualified column names and
      #     their associated values.
      # @param [Integer] timestamp
      # @param [org.apache.hadoop.hbase.client.RowLock] row_lock
      #
      # @return [Put] org.apache.hadoop.hbase.client.Put object
      #     corresponding to the arguments passed.
      def generate_put(row, columns = {}, timestamp = nil, row_lock = nil)
        put = row_lock ? Put.new(row.to_bytes, row_lock) : Put.new(row.to_bytes)

        columns.each do |name, value|
          family, qualifier = name.split(":")
          timestamp ?
            put.add(family.to_bytes, qualifier.to_bytes, timestamp, value.to_bytes) :
            put.add(family.to_bytes, qualifier.to_bytes, value.to_bytes)
        end

        return put
      end

      # Parse a Result object into a Hash.
      #
      # @param [Result] result
      #
      # @return [Hash] Fully qualified column names as keys
      #     and their corresponding values.
      def parse_result(result)
        output = {}

        result.list.each do |keyvalue|
          output[to_ruby_string(keyvalue.getColumn)] = to_ruby_string(keyvalue.getValue)
        end

        output["id"] = to_ruby_string(result.getRow)

        return output
      end

      def generate_column_descriptor(column_descriptor)
        raise ArgumentError, "a column descriptor is missing a name" unless column_descriptor.name
        raise "bloom_filter option not supported yet" if column_descriptor.bloom_filter

        if column_descriptor.compression
          compression =
            case column_descriptor.compression.to_s
              when 'none';   Compression::Algorithm::NONE.getName()
              when 'gz';     Compression::Algorithm::GZ.getName()
              when 'lzo';    Compression::Algorithm::LZO.getName()
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
end

port = ARGV[0] || 40000
DRb.start_service("druby://:#{port}", BigRecord::Driver::HbaseServer.new)
puts "Started drb server on port #{port}."
DRb.thread.join
