module Solr

  module AdapterMethods

    class SearchResults

      def initialize(solr_data={})
        @solr_data = solr_data
      end

      # Returns an array with the instances. This method
      # is also aliased as docs and records
      def results
        @solr_data[:docs]
      end

      # Returns the total records found. This method is
      # also aliased as num_found and total_hits
      def total
        @solr_data[:total]
      end

      # Returns the facets when doing a faceted search
      def facets
        @solr_data[:facets]
      end

      # Returns the highest score found. This method is
      # also aliased as highest_score
      def max_score
        @solr_data[:max_score]
      end

      # Returns the debugging information, notably the score 'explain'
      def debug
        @solr_data[:debug]
      end

      # FIXME: this is used only by find_articles so it shouldn't be declared here
      def exact_match
        @solr_data[:exact_match]
      end

      alias docs results
      alias records results
      alias num_found total
      alias total_hits total
      alias highest_score max_score
    end

  end # module AdapterMethods

end # module Solr