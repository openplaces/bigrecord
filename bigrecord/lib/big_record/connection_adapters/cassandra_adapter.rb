module BigRecord
  class Base
    def self.cassandra_connection(config) # :nodoc:
      begin
        require 'cassandra'
      rescue LoadError => e
        puts "[BigRecord] The 'cassandra' gem is needed for CassandraAdapter. Install it with: gem install cassandra"
        raise e
      end

      config = config.symbolize_keys
      
      client = Cassandra.new(config[:keyspace], config[:servers])
      ConnectionAdapters::CassandraAdapter.new(client, logger, [], config)
    end
  end

  module ConnectionAdapters
    class CassandraAdapter < AbstractAdapter
      @@emulate_booleans = true
      cattr_accessor :emulate_booleans

      LOST_CONNECTION_ERROR_MESSAGES = [
        "Server shutdown in progress",
        "Broken pipe",
        "Lost connection to HBase server during query",
        "HBase server has gone away"
      ]

      # data types
      TYPE_NULL     = 0x00;
      TYPE_STRING   = 0x01; # utf-8 strings
      TYPE_BOOLEAN  = 0x04; # delegate to YAML
      TYPE_BINARY   = 0x07; # byte[] => no conversion

      # string charset
      CHARSET = "utf-8"

      # utility constants
      NULL = "\000"

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config
      end

      def configuration
        @config.clone
      end

      def adapter_name #:nodoc:
        'Cassandra'
      end

      def supports_migrations? #:nodoc:
        false
      end

      # CONNECTION MANAGEMENT ====================================

      def disconnect!
        @connection.disconnect!
        super
      end

      # DATABASE STATEMENTS ======================================

      def update_raw(table_name, row, values, timestamp)
        result = nil
        log "UPDATE #{table_name} SET #{values.inspect if values} WHERE ROW=#{row};" do
          result = @connection.insert(table_name, row, data_to_cassandra_format(values), {:timestamp => timestamp})
        end
        result
      end

      def update(table_name, row, values, timestamp)
        serialized_collection = {}
        values.each do |column, value|
          serialized_collection[column] = serialize(value)
        end
        update_raw(table_name, row, serialized_collection, timestamp)
      end

      def get_raw(table_name, row, column, options={})
        result = nil
        log "SELECT (#{column}) FROM #{table_name} WHERE ROW=#{row};" do
          super_column, name = column.split(":")
          result = @connection.get(table_name, row, super_column, name)
        end
        result
      end

      def get(table_name, row, column, options={})
        serialized_result = get_raw(table_name, row, column, options)
        result = nil
        if serialized_result.is_a?(Array)
          result = serialized_result.collect{|e| deserialize(e)}
        else
          result = deserialize(serialized_result)
        end
        result
      end

      def get_columns_raw(table_name, row, columns, options={})
        result = {}
        result["id"] = row
        
        log "SELECT (#{columns.join(", ")}) FROM #{table_name} WHERE ROW=#{row};" do
          requested_columns = columns_to_cassandra_format(columns)
          super_columns = requested_columns.keys
          
          if super_columns.size == 1 && requested_columns[super_columns.first].size > 0
            column_names = requested_columns[super_columns.first]

            values = @connection.get_columns(table_name, row, super_columns.first, column_names)

            column_names.each_index do |id|
              full_key = super_columns.first + ":" + column_names[id].to_s
              result[full_key] = values[id] unless values[id].nil?
            end
          else
            values = @connection.get_columns(table_name, row, super_columns)

            super_columns.each_index do |id|
              next if values[id].nil?
              
              values[id].each do |column_name, value|
                next if value.nil?
                
                full_key = super_columns[id] + ":" + column_name
                result[full_key] = value
              end
            end
          end
        end
        result
      end

      def get_columns(table_name, row, columns, options={})
        row_cols = get_columns_raw(table_name, row, columns, options)
        return nil unless row_cols

        result = {}
        row_cols.each do |key,value|
          begin
            result[key] =
            if key == 'id'
              value
            else
              deserialize(value)
            end
          rescue Exception => e
            puts "Could not load column value #{key} for row=#{row.name}"
          end
        end
        result
      end

      def get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row = nil)
        result = []
        log "SCAN (#{columns.join(", ")}) FROM #{table_name} WHERE START_ROW=#{start_row} AND STOP_ROW=#{stop_row} LIMIT=#{limit};" do
          options = {}
          options[:start] = start_row if start_row
          options[:finish] = stop_row if stop_row
          options[:count] = limit if limit

          keys = @connection.get_range(table_name, options)

          # This will be refactored. Don't make fun of me yet.
          if !keys.empty?
            keys.each do |key|
              row = {}
              row["id"] = key.key

              key.columns.each do |s_col|
                super_column = s_col.super_column
                super_column_name = super_column.name

                super_column.columns.each do |column|
                  full_key = super_column_name + ":" + column.name
                  row[full_key] = column.value
                end
              end

              result << row
            end
          end
        end
        result
      end

      def get_consecutive_rows(table_name, start_row, limit, columns, stop_row = nil)
        rows = get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row)

        result = rows.collect do |row|
          cols = {}
          row.each do |key,value|
            begin
              cols[key] = (key == "id") ? value : deserialize(value)
            rescue Exception => e
              puts "Could not load column value #{key} for row=#{row.name}"
            end
          end
          cols
        end
        result
      end

      def delete(table_name, row)
        @connection.remove(table_name.to_s, row)
      end

      def delete_all(table_name)
        raise NotImplementedError
      end

      # SERIALIZATION STATEMENTS =================================

      # Serialize the given value
      def serialize(value)
        case value
        when NilClass then NULL
        when String then build_serialized_value(TYPE_STRING, value)
        else value.to_yaml
        end
      end

      # Serialize an object in a given type
      def build_serialized_value(type, value)
        type.chr + value
      end

      # Deserialize the given string. This method supports both the pure YAML format and
      # the type header format.
      def deserialize(str)
        return unless str

        #	stay compatible with the old serialization code
        #	YAML documents start with "--- " so if we find that sequence at the beginning we
        #	consider it as a serialized YAML value, else it's the new format with the type header
        if str[0..3] == "--- "
          YAML::load(str) if str
        else
          deserialize_with_header(str)
        end
      end

      # Deserialize the given string assumed to be in the type header format.
      def deserialize_with_header(data)
        return unless data and data.size >= 2

        # the type of the data is encoded in the first byte
        type = data[0];

        case type
        when TYPE_NULL then nil
        when TYPE_STRING then data[1..-1]
        when TYPE_BINARY then data[1..-1]
        else data
        end
      end
      
    protected

      def data_to_cassandra_format(data = {})
        super_columns = {}
        
        data.each do |name, value|
          super_column, column = name.split(":")
          super_columns[super_column.to_s] = {} unless super_columns.has_key?(super_column.to_s)
          super_columns[super_column.to_s][column.to_s] = value
        end

        return super_columns
      end

      def columns_to_cassandra_format(column_names = [])
        super_columns = {}

        column_names.each do |name|
          super_column, sub_column = name.split(":")
          
          super_columns[super_column.to_s] = [] unless super_columns.has_key?(super_column.to_s)
          super_columns[super_column.to_s] << sub_column
        end

        return super_columns
      end

      def log(str, name = nil)
        if block_given?
          if @logger and @logger.level <= Logger::INFO
            result = nil
            seconds = Benchmark.realtime { result = yield }
            @runtime += seconds
            log_info(str, name, seconds)
            result
          else
            yield
          end
        else
          log_info(str, name, 0)
          nil
        end
      rescue Exception => e
        # Log message and raise exception.
        # Set last_verfication to 0, so that connection gets verified
        # upon reentering the request loop
        @last_verification = 0
        message = "#{e.class.name}: #{e.message}: #{str}"
        log_info(message, name, 0)
        raise e
      end

      def log_info(str, name, runtime)
        return unless @logger

        @logger.debug(
          format_log_entry(
            "#{name.nil? ? "CASSANDRA" : name} (#{sprintf("%f", runtime)})",
            str.gsub(/ +/, " ")
          )
        )
      end

      def format_log_entry(message, dump = nil)
        if BigRecord::Base.colorize_logging
          if @@row_even
            @@row_even = false
            message_color, dump_color = "4;36;1", "0;1"
          else
            @@row_even = true
            message_color, dump_color = "4;35;1", "0"
          end

          log_entry = "  \e[#{message_color}m#{message}\e[0m   "
          log_entry << "\e[#{dump_color}m%#{String === dump ? 's' : 'p'}\e[0m" % dump if dump
          log_entry
        else
          "%s  %s" % [message, dump]
        end
      end
    end
  end
end