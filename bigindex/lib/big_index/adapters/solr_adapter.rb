module BigIndex
  module Adapters

    class SolrAdapter < AbstractAdapter

      include ::Solr::AdapterMethods

      attr_reader :connection

      # BigIndex Adapter API methods ====================================

      def adapter_name
        'solr'
      end

      def default_type_field
        "type_s_mv"
      end

      def default_primary_key_field
        "pk_s"
      end

      def process_index_batch(items, loop, options = {})
        unless items.empty?
          # This checks that if the item has a method indexable? defined, then it will determine
          # whether or not to index the item based on that method's returned boolean value.
          items_to_index = items.select { |item| item.respond_to?(:indexable?) ? item.indexable? : true }

          unless items_to_index.empty?
            docs = items_to_index.collect{|content| content.to_solr_doc}
            if options[:only_generate]
              # Collect the documents. This is to be used within a mapred job.
              docs.each do |doc|
                key = doc['id']

                # Cannot have \n and \t in the value since they are
                # document and field separators respectively
                value = doc.to_xml.to_s
                value = value.gsub("\n", "__ENDLINE__")
                value = value.gsub("\t", "__TAB__")

                puts "#{key}\t#{value}"
              end
            else
              solr_add(docs)
              solr_commit if options[:commit]
            end
          else
            break
          end
        end
      end

      def drop_index(model)
        @connection.logger = model.logger if model.respond_to?(:logger)
        @connection.solr_execute(Solr::Request::Delete.new(:query => "type_s_mv:\"#{model.name}\""))
      end

      def get_field_type(field_type)
        if field_type.is_a?(Symbol)
          case field_type
            when :float then                return "f"
            when :integer then              return "i"
            when :boolean then              return "b"
            when :string then               return "s"
            when :date then                 return "d"
            when :range_float then          return "rf"
            when :range_integer then        return "ri"
            when :ngrams then               return "ngrams"
            when :autocomplete then         return "auto"
            when :lowercase then            return "lc"
            when :exact_match then          return "em"
            when :geo then                  return "geo"
            when :text then                 return "t"
            when :text_not_stored then      return "t_ns"
            when :text_not_indexed then     return "t_ni"
            when :integer_array then        return "i_mv"
            when :text_array then           return "t_mv"
            when :text_array_not_stored then return "t_mv_ns"
            when :float_array then          return "f_mv"
            when :boolean_array then        return "b_mv"
            when :date_array then           return "d_mv"
            when :string_array then         return "s_mv"
            when :range_integer_array then  return "ri_mv"
            when :range_float_array then    return "rf_mv"
            when :ngrams_array then         return "ngrams_mv"
            when :autocomplete_array then   return "auto_mv"
            when :lowercase_array then      return "lc_mv"
            when :exact_match_array then    return "em_mv"
          else
            raise "Unknown field_type symbol: #{field_type}"
          end
        elsif field_type.is_a?(String)
          return field_type
        else
          raise "Unknown field_type class: #{field_type.class}: #{field_type}"
        end
      end

      def index_save(model)
        configuration = model.index_configuration

        results = []
        if configuration[:if] && evaluate_condition(configuration[:if], model)
          results << solr_add(to_solr_doc(model))
          results << solr_commit if configuration[:auto_commit]
        end

        !results.map{|result| result.status_code == "0"}.include?(false)
      end

      def index_destroy(model)
        configuration = model.index_configuration

        results = []

        results << solr_delete(model.index_id)
        results << solr_delete(":#{model.record_id}")
        results << solr_commit if configuration[:auto_commit]

        !results.map{|result| result.status_code == "0"}.include?(false)
      end

      def find_by_index(model, query, options={})
        data = parse_query(model, query, options)

        return parse_results(model, data, options).results if data
      end

      def find_values_by_index(model, query, options={})
        data = parse_query(model, query, options)

        return parse_results(model, data, {:format => :values}).results if data
      end

      def find_ids_by_index(model, query, options={})
        data = parse_query(model, query, options)

        return parse_results(model, data, {:format => :ids}).results if data
      end

      # End of BigIndex Adapter API ====================================

    private

      def initialize(name, options)
        @connection = Solr::Base.new(options)

        super(name, options)
      end

    end # class SolrAdapter

  end # module Adapters
end # module BigIndex
