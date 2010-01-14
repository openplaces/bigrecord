require File.dirname(__FILE__) + '/exceptions'
require File.dirname(__FILE__) + '/column_descriptor'
require 'drb'

# The name of the java String class conflicts with ruby's String class.
module Java
  java_import "java.lang.String"
  java_import "java.lang.Exception"
end

class String
  def to_bytes
    Java::String.new(self).getBytes
  end
end


module BigRecord
  module Driver

    class Server
      java_import "java.io.IOException"

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

    protected

      def to_ruby_string(byte_string)
        Java::String.new(byte_string).to_s
      end

      # Try to recover from network related exceptions. e.g. hbase has been restarted and the
      # cached connections in @tables are no longer valid. Every method in this class (except connect_table)
      # should have its code wrapped by a call to this method.
      def safe_exec
        yield
      rescue IOException => e
        puts "A network error occured: #{e.message}. Trying to recover..."
        init_connection
        begin
          yield
        rescue Exception, Java::Exception => e2
          if e2.class == e.class
            puts "Failed to recover the connection."
          else
            puts "Failed to recover the connection but got a different error this time: #{e2.message}."
          end
          puts "Stack trace:"
          puts e2.backtrace.join("\n")

          if e2.kind_of?(NativeException)
            raise BigRecord::Driver::JavaError, e2.message
          else
            raise e2
          end
        end
        puts "Connection recovered successfully..."
      rescue Exception => e
        puts "\n#{e.class.name}: #{e.message}"
        puts e.backtrace.join("\n")
        raise e
      end

    end

  end
end
