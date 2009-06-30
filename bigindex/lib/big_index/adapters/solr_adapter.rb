module BigIndex
  module Adapters

    class SolrAdapter < AbstractAdapter

      def adapter_name
        'solr'
      end

      def process_index_batch(items, loop, options={})
        raise NotImplementedError
      end

      def drop_index
        raise NotImplementedError
      end

      def process_index_batch(items, loop, options={})
        raise NotImplementedError
      end

      def find_values_by_index(query, options={})
        []
      end

      def find_by_index(query, options={})
        []
      end

      def find_ids_by_index(query, options={})
        []
      end

      private

      def initialize(name, options)
        super(name, options)
      end

    end # class SolrAdapter

  end # module Adapters
end # module BigIndex
