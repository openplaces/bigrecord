require 'set'
require 'hbase'

module BigRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.hbase_rest_connection(config) # :nodoc:
      config = config.symbolize_keys

      api_address = config[:api_address]

      hbase = HBase::Client.new(api_address)

      ConnectionAdapters::HbaseRestAdapter.new(hbase, logger, [], config)
    end
  end

  module ConnectionAdapters
    class HbaseRestAdapter < AbstractAdapter
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

        connect
      end

      def configuration
        @config.clone
      end

      def adapter_name #:nodoc:
        'HBase-rest'
      end

      def supports_migrations? #:nodoc:
        true
      end

      # CONNECTION MANAGEMENT ====================================

      def active?
        true
      end

      def reconnect!
      end

      def disconnect!
      end


      # DATABASE STATEMENTS ======================================

      def columns_to_hbase_format(data = {})
        # Convert it to the hbase-ruby format
        # TODO: Add this function to hbase-ruby instead.
        data.map{|col, content| {:name => col.to_s, :value => content}}
      end

      def update_raw(table_name, row, values, timestamp)
        result = nil
        
        columns = columns_to_hbase_format(values)
        timestamp = Time.now.to_bigrecord_timestamp
        
        log "UPDATE #{table_name} SET #{values.inspect if values} WHERE ROW=#{row};" do
          @logger.debug("COLUMNS #{columns.class} " + columns.inspect)
          @connection.create_row(table_name, row, timestamp, columns)
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
        timestamp = options[:timestamp] || nil
        log "SELECT (#{column}) FROM #{table_name} WHERE ROW=#{row};" do
          columns = @connection.show_row(table_name, row, timestamp, column, options).columns
          
          result = (columns.size == 1) ? columns.first.value : columns.map(&:value)
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

      def get_columns_raw(table_name, row, columns = nil, options={})
        result = {}
        
        timestamp = options[:timestamp] || nil
        
        log "SELECT (#{columns.join(", ")}) FROM #{table_name} WHERE ROW=#{row};" do
          row = @connection.show_row(table_name, row, timestamp, columns, options)
          result.merge!({'id' => row.name})
          columns = row.columns
          columns.each{ |col| result.merge!({col.name => col.value}) }
        end
        result
      end

      def get_columns(table_name, row, columns, options={})
        row_cols = get_columns_raw(table_name, row, columns, options)
        result = {}
        return nil unless row_cols

        row_cols.each do |key, col|
          result[key] =
          if key == 'id'
            col
          else
            deserialize(col)
          end
        end
        result
      end

      def get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row = nil)
        result = nil
        log "SCAN (#{columns.join(", ")}) FROM #{table_name} WHERE START_ROW=#{start_row} AND STOP_ROW=#{stop_row} LIMIT=#{limit};" do
          scanner = @connection.open_scanner(table_name, columns, start_row, stop_row)
          result = @connection.get_rows(scanner, limit)
          @connection.close_scanner(scanner)
        end
        result
      end

      def get_consecutive_rows(table_name, start_row, limit, columns, stop_row = nil)
        rows = get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row)
        result = rows.collect do |row_cols|
          cols = {}
          row_cols.each do |key, col|
            begin
              cols[key] =
              if key == 'id'
                col
              else
                deserialize(col)
              end
            rescue Exception => e
              puts "Could not load column value #{key} for row=#{row_cols['id']}"
            end
          end
          cols
        end
        result
      end

      def delete(table_name, row, timestamp = nil)
        timestamp ||= Time.now.to_bigrecord_timestamp
        result = nil
        log "DELETE FROM #{table_name} WHERE ROW=#{row};" do
          result = @connection.delete_row(table_name, row, timestamp)
        end
        result
      end

      def truncate_table(table_name)
      end


      # SCHEMA STATEMENTS ========================================

      def initialize_schema_migrations_table
        sm_table = BigRecord::Migrator.schema_migrations_table_name

        unless table_exists?(sm_table)
          create_table(sm_table) do |t|
            t.family :attribute, :versions => 1
          end
        end
      end

      def get_all_schema_versions
        sm_table = BigRecord::Migrator.schema_migrations_table_name

        get_consecutive_rows(sm_table, nil, nil, ["attribute:version"]).map{|version| version["attribute:version"]}
      end

      def table_exists?(table_name)
        log "TABLE EXISTS? #{table_name};" do
          @connection.list_tables.map(&:name).include?(table_name)
        end
      end

      def create_table(table_name, options = {})
        table_definition = TableDefinition.new

        yield table_definition if block_given?

        if options[:force] && table_exists?(table_name)
          drop_table(table_name)
        end

        result = nil
        log "CREATE TABLE #{table_name} (#{table_definition.column_families_list});" do
          result = @connection.create_table(table_name, table_definition.to_adapter_format)
        end
        result
      end

      def drop_table(table_name)
        result = nil
        log "DROP TABLE #{table_name};" do
          result = @connection.destroy_table(table_name)
        end
        result
      end

      def add_column_family(table_name, column_name, options = {})
        column = BigRecordDriver::ColumnDescriptor.new(column_name.to_s, options)

        result = nil
        log "ADD COLUMN TABLE #{table_name} COLUMN #{column_name} (#{options.inspect});" do
          result = @connection.add_column(table_name, column)
        end
        result
      end

      alias :add_family :add_column_family

      def remove_column_family(table_name, column_name)
        result = nil
        log "REMOVE COLUMN TABLE #{table_name} COLUMN #{column_name};" do
          result = @connection.remove_column(table_name, column_name)
        end
        result
      end

      alias :remove_family :remove_column_family

      def modify_column_family(table_name, column_name, options = {})
        column = BigRecordDriver::ColumnDescriptor.new(column_name.to_s, options)

        result = nil
        log "MODIFY COLUMN TABLE #{table_name} COLUMN #{column_name} (#{options.inspect});" do
          result = @connection.modify_column(table_name, column)
        end
        result
      end

      alias :modify_family :modify_column_family

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
        else nil
        end
      end

      private
        def connect
        end

      protected
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
              "#{name.nil? ? "HBASE" : name} (#{sprintf("%f", runtime)})",
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

    class TableDefinition

      def initialize
        @column_families = []
      end

      # Returns a column family for the column with name +name+.
      def [](name)
        @column_families.find {|column| column.name.to_s == name.to_s}
      end

      def column_family(name, options = {})
        column = self[name] || BigRecordDriver::ColumnDescriptor.new(name.to_s, options)

        @column_families << column unless @column_families.include? column
        self
      end

      alias :family :column_family

      def to_adapter_format
        @column_families
      end

      def column_families_list
        @column_families.map(&:name).join(", ")
      end

    end

  end
end
