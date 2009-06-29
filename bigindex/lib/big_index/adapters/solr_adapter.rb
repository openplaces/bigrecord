
module BigIndex
  module Adapters

    class SolrAdapter < AbstractAdapter

      def find_values_by_index(query, options={})
        []
      end

      def find_by_index(query, options={})
        []
      end

      def find_id_by_index(query, options={})
        []
      end

      def initialize(name, options)
        super(name, options)
      end

    end # class SolrAdapter

  end # module Adapters
end # module BigIndex
