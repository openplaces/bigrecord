module BigIndex
  module Adapters

    class AbstractAdapter

      attr_reader :name, :options

      def rebuild_index(options={}, finder_options={})
        raise NotImplementedError
      end

      def process_index_batch(items, loop, options={})
        raise NotImplementedError
      end

      def index(field, options={}, &block)
        raise NotImplementedError
      end

      def add_index_field(field, block)
        raise NotImplementedError
      end

      def find_values_by_index(query, options={})
        raise NotImplementedError
      end

      def find_by_index(query, options={})
        raise NotImplementedError
      end

      def find_id_by_index(query, options={})
        raise NotImplementedError
      end


      private

      def initialize(name, options)
        @name = name
        @options = options
      end

    end # class AbstractAdapter

  end # module Adapters
end # module BigIndex
