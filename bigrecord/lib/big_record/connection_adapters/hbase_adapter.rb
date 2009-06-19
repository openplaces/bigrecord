require 'rubygems'
require 'big_record/connection_adapters/abstract_adapter'
require 'big_record/connection_adapters/column'
require 'big_record/connection_adapters/view'
require 'set'
require 'drb'

module BigRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.hbase_connection(config) # :nodoc:
      config = config.symbolize_keys
      config[:master]       ||= 'localhost:60000'
      config[:regionserver] ||= 'regionserver:60020'
      config[:drb_host]     ||= 'localhost'
      config[:drb_port]     ||= 40000

      master        = config[:master]
      regionserver  = config[:regionserver]
      drb_host      = config[:drb_host]
      drb_port      = config[:drb_port]

      # Only start the drb service once. If it's not started yet we get an exception and
      # recover by starting it.
      begin
        DRb.current_server
      rescue DRb::DRbServerNotFound
        DRb.start_service
      end
      hbase = DRbObject.new(nil, "druby://#{drb_host}:#{drb_port}")

      ConnectionAdapters::HbaseAdapter.new(hbase, logger, [master, regionserver], config)
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
        false
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
          result = rpc(:update, table_name, row, values, timestamp)
        end
        result
      end

      def update(table_name, row, values, timestamp)
        serialized_collection = {}
          values.each do |column, value|
            serialized_collection[column] = value.to_yaml
        end
        update_raw(table_name, row, serialized_collection, timestamp)
      end

      def get_raw(table_name, row, column, options={})
        result = nil
        log "SELECT (#{column}) FROM #{table_name} WHERE ROW=#{row};" do
          result = rpc(:get, table_name, row, column, options)
        end
        result
      end

      def get(table_name, row, column, options={})
        serialized_result = get_raw(table_name, row, column, options)
        result = nil
        if serialized_result.is_a?(Array)
          result = serialized_result.collect{|e| YAML::load(e)}
        else
          result = YAML::load(serialized_result) if serialized_result
        end
        result
      end


      def get_columns_raw(table_name, row, columns, options={})
        result = {}
        log "SELECT (#{columns.join(", ")}) FROM #{table_name} WHERE ROW=#{row};" do
          result = rpc(:get_columns, table_name, row, columns, options)
        end
        result
      end

      def get_columns(table_name, row, columns, options={})
        row_cols = get_columns_raw(table_name, row, columns, options)
        result = {}
        return nil unless row_cols

        row_cols.each do |key, col|
          result[key] =
          if key == 'attribute:id'
            col
          else
            YAML::load(col) if col
          end
        end
        result
      end

      def get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row = nil)
        result = nil
        log "SCAN (#{columns.join(", ")}) FROM #{table_name} WHERE START_ROW=#{start_row} AND STOP_ROW=#{stop_row} LIMIT=#{limit};" do
          result = rpc(:get_consecutive_rows, table_name, start_row, limit, columns, stop_row)
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
              if key == 'attribute:id'
                col
              else
                YAML::load(col) if col
              end
            rescue Exception => e
              puts "Could not load column value #{key} for row=#{row_cols['attribute:id']}"
            end
          end
          cols
        end
        result
      end

      def delete(table_name, row)
        result = nil
        log "DELETE FROM #{table_name} WHERE ROW=#{row};" do
          result = rpc(:delete, table_name, row)
        end
        result
      end

      def delete_all(table_name)
        result = nil
        log "DELETE FROM #{table_name};" do
          result = rpc(:delete_all, table_name)
        end
        result
      end

      def stop_drb_service
        result = nil
        log "STOP DRB SERVICE;" do
          result = rpc(:stop_drb_service)
        end
        result
      end

      # SCHEMA STATEMENTS ========================================

      def create_table(table_name, column_families)
        result = nil
#        log "CREATE TABLE #{table_name} (#{column_families});" do
          result = rpc(:create_table, table_name, column_families)
#        end
        result
      end

      def drop_table(table_name)
        result = nil
        log "DROP TABLE #{table_name};" do
          result = rpc(:drop_table, table_name)
        end
        result
      end


      private
        def connect
          @connection.configure(@config)
        rescue DRb::DRbConnError
          raise BigRecord::ConnectionFailed, "Failed to connect to the DRb server (jruby) " +
                                                "at #{@config[:drb_host]}:#{@config[:drb_port]}."
        end

        def rpc(method_id, *args)
          @connection.send(method_id, *args)
        rescue
          connect
          @connection.send(method_id, *args)
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
  end
end
