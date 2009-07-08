require 'benchmark'
require 'date'
require 'bigdecimal'
require 'bigdecimal/util'

require 'big_record/connection_adapters/abstract/database_statements'
require 'big_record/connection_adapters/abstract/quoting'
require 'big_record/connection_adapters/abstract/connection_specification'

module BigRecord
  module ConnectionAdapters # :nodoc:
    # All the concrete database adapters follow the interface laid down in this class.
    # You can use this interface directly by borrowing the database connection from the Base with
    # Base.connection.
    #
    # Most of the methods in the adapter are useful during migrations.  Most
    # notably, SchemaStatements#create_table, SchemaStatements#drop_table,
    # SchemaStatements#add_index, SchemaStatements#remove_index,
    # SchemaStatements#add_column, SchemaStatements#change_column and
    # SchemaStatements#remove_column are very useful.
    class AbstractAdapter
      include Quoting, DatabaseStatements#, SchemaStatements
      @@row_even = true

      def initialize(connection, logger = nil) #:nodoc:
        @connection, @logger = connection, logger
        @runtime = 0
        @last_verification = 0
      end

      # Returns the human-readable name of the adapter.  Use mixed case - one
      # can always use downcase if needed.
      def adapter_name
        'Abstract'
      end

      # Does this adapter support migrations?  Backend specific, as the
      # abstract adapter always returns +false+.
      def supports_migrations?
        false
      end

      # Does this adapter support using DISTINCT within COUNT?  This is +true+
      # for all adapters except sqlite.
      def supports_count_distinct?
        false
      end

      def supports_ddl_transactions?
        false
      end

      # Should primary key values be selected from their corresponding
      # sequence before the insert statement?  If true, next_sequence_value
      # is called before each insert to set the record's primary key.
      # This is false for all adapters but Firebird.
      def prefetch_primary_key?(table_name = nil)
        false
      end

      def reset_runtime #:nodoc:
        rt, @runtime = @runtime, 0
        rt
      end

      # QUOTING ==================================================

      # Override to return the quoted table name if the database needs it
      def quote_table_name(name)
        name
      end

      # REFERENTIAL INTEGRITY ====================================

      # Override to turn off referential integrity while executing +&block+
      def disable_referential_integrity(&block)
        yield
      end

      # CONNECTION MANAGEMENT ====================================

      # Is this connection active and ready to perform queries?
      def active?
        @active != false
      end

      # Close this connection and open a new one in its place.
      def reconnect!
        @active = true
      end

      # Close this connection
      def disconnect!
        @active = false
      end

      # Returns true if its safe to reload the connection between requests for development mode.
      # This is not the case for Ruby/MySQL and it's not necessary for any adapters except SQLite.
      def requires_reloading?
        false
      end

      # Lazily verify this connection, calling +active?+ only if it hasn't
      # been called for +timeout+ seconds.
      def verify!(timeout)
        now = Time.now.to_i
        if (now - @last_verification) > timeout
          reconnect! unless active?
          @last_verification = now
        end
      end

      # Provides access to the underlying database connection. Useful for
      # when you need to call a proprietary method such as postgresql's lo_*
      # methods
      def raw_connection
        @connection
      end

      # DATABASE STATEMENTS ======================================

      def update_raw(table_name, row, values, timestamp)
        raise NotImplementedError
      end

      def update(table_name, row, values, timestamp)
        raise NotImplementedError
      end

      def get_raw(table_name, row, column, options={})
        raise NotImplementedError
      end

      def get(table_name, row, column, options={})
        raise NotImplementedError
      end

      def get_columns_raw(table_name, row, columns, options={})
        raise NotImplementedError
      end

      def get_columns(table_name, row, columns, options={})
        raise NotImplementedError
      end

      def get_consecutive_rows_raw(table_name, start_row, limit, columns, stop_row = nil)
        raise NotImplementedError
      end

      def get_consecutive_rows(table_name, start_row, limit, columns, stop_row = nil)
        raise NotImplementedError
      end

      def delete(table_name, row)
        raise NotImplementedError
      end

      def delete_all(table_name)
        raise NotImplementedError
      end

      # SCHEMA STATEMENTS ========================================

      def create_table(table_name, column_families)
        raise NotImplementedError
      end

      def drop_table(table_name)
        raise NotImplementedError
      end

    end # class AbstractAdapter
  end # module ConnectionAdapters
end # module BigRecord


# Open the time class to add logic for the hbase timestamp
class Time
  # Return this time is the hbase timestamp format, i.e. a 'long'. The 4 high bytes contain
  # the number of seconds since epoch and the 4 low bytes contain the microseconds. That
  # format is an arbitrary one and could have been something else.
  def to_bigrecord_timestamp
    (self.to_i << 32) + self.usec
  end

  def self.from_bigrecord_timestamp(timestamp)
    Time.at(timestamp >> 32, timestamp & 0xFFFFFFFF)
  end

end
