module BigIndex
  module Adapters

    class SolrAdapter < AbstractAdapter

      attr_reader :connection

      def adapter_name
        'solr'
      end

      def default_type_field
        "type_s_mv"
      end

      def default_primary_key_field
        "pk_s"
      end

      def process_index_batch(items, loop, options={})
      end

      def drop_index(model)
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

      def find_by_index(query, options={})
        data = parse_query(query, options)

        return parse_results(data, options) if data
      end

      def find_values_by_index(query, options={})
        data = parse_query(query, options)

        return parse_results(data, {:format => :values}) if data
      end

      def find_ids_by_index(query, options={})
        data = parse_query(query, options)

        return parse_results(data, {:format => :ids}) if data
      end

    private

      def initialize(name, options)
        @connection = Solr::Base.new(options)

        super(name, options)
      end


      def parse_query(query, options = {})
        raise NotImplementedError
      end

      def parse_results(data, options)
        raise NotImplementedError
      end


    end # class SolrAdapter

  end # module Adapters
end # module BigIndex
