require 'rubygems'
require 'set'
require 'drb'

unless defined?(BigRecordDriver)
 begin
   require File.join(File.dirname(__FILE__), "..", "..", "..", "..", "bigrecord-driver", "lib", "big_record_driver")
 rescue
   puts "Couldn't load bigrecord_server gem"
   #require 'rubygems'
   #gem 'bigrecord-driver'
   #require 'big_record_driver'
 end
end

module BigRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.hbase_connection(config) # :nodoc:
      config = config.symbolize_keys

      quorum         = config[:quorum]
      zk_client_port = config[:zk_client_port]
      drb_host       = config[:drb_host]
      drb_port       = config[:drb_port]

      hbase = BigRecordDriver::Client.new(config)

      ConnectionAdapters::HbaseAdapter.new(hbase, logger, [quorum, zk_client_port], config)
    end
  end

  module ConnectionAdapters
    class HbaseAdapter < AbstractAdapter
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
#      TYPE_INTEGER  = 0x02; # delegate to YAML
#      TYPE_FLOAT    = 0x03; # fixed 1 byte
      TYPE_BOOLEAN  = 0x04; # delegate to YAML
#      TYPE_MAP      = 0x05; # delegate to YAML
#      TYPE_DATETIME = 0x06; # delegate to YAML
      TYPE_BINARY   = 0x07; # byte[] => no conversion

      # string charset
      CHARSET = "utf-8"

      # utility constants
      NULL = "\000"
#      TRUE = "\001"
#      FALSE = "\000"

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config

        connect
      end

      def configuration
        @config.clone
      end

      def adapter_name #:nodoc:
        'HBase'
      end

      def supports_migrations? #:nodoc:
        true
      end

      # CONNECTION MANAGEMENT ====================================

      def active?
        @connection.ping
      rescue BigRecordError
        false
      end

      def reconnect!
        disconnect!
        connect
      end

      def disconnect!
        @connection.close rescue nil
      end


      # DATABASE STATEMENTS ======================================

      def update_raw(table_name, row, values, timestamp)
        result = nil
        log "UPDATE #{table_name} SET #{values.inspect if values} WHERE ROW=#{row};" do
          result = @connection.update(table_name, row, values, timestamp)
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
          result = @connection.get(table_name, row, column, options)
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
        log "SELECT (#{columns.join(", ")}) FROM #{table_name} WHERE ROW=#{row};" do
          result = @connection.get_columns(table_name, row, columns, options)
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
          result = @connection.get_consecutive_rows(table_name, start_row, limit, columns, stop_row)
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
        result = nil
        log "DELETE FROM #{table_name} WHERE ROW=#{row};" do
          result = @connection.delete(table_name, row, timestamp)
        end
        result
      end

      def truncate_table(table_name)
        result = nil
        log "TRUNCATE TABLE #{table_name}" do
          result = @connection.truncate_table(table_name)
        end
        result
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
          @connection.table_exists?(table_name)
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
          result = @connection.drop_table(table_name)
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
          @connection.configure(@config)
        rescue DRb::DRbConnError
          raise BigRecord::ConnectionFailed, "Failed to connect to the DRb server (jruby) " +
                                                "at #{@config[:drb_host]}:#{@config[:drb_port]}."
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
