module BigIndex
  module Adapters

    class SolrAdapter < AbstractAdapter

      def adapter_name
        'solr'
      end

      def process_index_batch(items, loop, options={})
      end

      def drop_index
      end

      def get_field_type(type)
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
