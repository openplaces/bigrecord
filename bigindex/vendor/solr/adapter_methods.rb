require File.dirname(__FILE__) + "/adapter_methods/solr_result"
require File.dirname(__FILE__) + "/adapter_methods/search_results"

module Solr

  module AdapterMethods

    public

      def solr_add(add_xml)
        @connection.solr_execute(Solr::Request::AddDocument.new(add_xml))
      end

      def solr_delete(solr_ids)
        @connection.solr_execute(Solr::Request::Delete.new(:id => solr_ids))
      end

      def solr_commit
        @connection.solr_execute(Solr::Request::Commit.new)
      end

      # Optimizes the Solr index. Solr says:
      #
      # Optimizations can take nearly ten minutes to run.
      # We are presuming optimizations should be run once following large
      # batch-like updates to the collection and/or once a day.
      #
      # One of the solutions for this would be to create a cron job that
      # runs every day at midnight and optmizes the index:
      #   0 0 * * * /your_rails_dir/script/runner -e production "BigIndex::Repository.adapters[:default].solr_optimize"
      #
      def solr_optimize
        @connection.solr_execute(Solr::Request::Optimize.new)
      end

      def all_classes_for_solr(model)
        all_classes = []
        current_class = model.class
        base_class = current_class.base_class
        while current_class != base_class
          all_classes << current_class
          current_class = current_class.superclass
        end
        all_classes << base_class
        return all_classes
      end

      # TODO: This is a big ugly method that needs to be refactored
      def to_solr_doc(model)
        configuration = model.index_configuration
        logger = model.logger || nil

        doc = Solr::Document.new
        doc.boost = validate_boost(configuration[:boost], model) if configuration[:boost]

        doc << {:id => model.index_id,
                configuration[:type_field] => all_classes_for_solr(model),
                configuration[:primary_key_field] => model.record_id.to_s}

        # iterate through the fields and add them to the document,
        configuration[:fields].each do |field|
          field_name = field.field_name
          field_type = get_field_type(field.field_type) if field.field_type
          field_boost= field[:boost] if field[:boost]

          field_type  ||= configuration[:facets] && configuration[:facets].include?(field) ? :facet : :text
          field_boost ||= configuration[:default_boost]

          # add the field to the document, but only if it's not the id field
          # or the type field (from single table inheritance), since these
          # fields have already been added above.
          if field_name.to_s != model.class.primary_key and field_name.to_s != "type"
            suffix = get_field_type(field_type)
            value = model.send("#{field_name}_for_index")
            if value.is_a?(Hash)
              boost = value.values.first
              value = value.keys.first
            end

            value = set_value_if_nil(field_type) if value.to_s == ""

            # This next line ensures that e.g. nil dates are excluded from the
            # document, since they choke Solr. Also ignores e.g. empty strings,
            # but these can't be searched for anyway:
            # http://www.mail-archive.com/solr-dev@lucene.apache.org/msg05423.html
            next if value.nil? || value.to_s.strip.empty?

            [value].flatten.each do |v|
              v = set_value_if_nil(suffix) if value.to_s == ""
              field = Solr::Field.new("#{field_name}_#{suffix}" => ERB::Util.html_escape(v.to_s))
              field.boost = validate_boost((boost || field_boost), model)
              doc << field
            end
          end
        end

        add_includes(doc, model) if configuration[:include]
        return doc
      end

      def add_includes(doc, model)
        configuration = model.index_configuration

        if configuration[:include].is_a?(Array)
          configuration[:include].each do |association|
            data = ""
            klass = association.to_s.singularize
            case model.class.reflect_on_association(association).macro
            when :has_many, :has_and_belongs_to_many
              records = model.send(association).to_a
              unless records.empty?
                records.each{|r| data << r.attributes.inject([]){|k,v| k << "#{v.first}=#{v.last}"}.join(" ")}
                doc["#{klass}_t"] = data
              end
            when :has_one, :belongs_to
              record = model.send(association)
              unless record.nil?
                data = record.attributes.inject([]){|k,v| k << "#{v.first}=#{v.last}"}.join(" ")
                doc["#{klass}_t"] = data
              end
            end
          end
        end
      end

      def validate_boost(boost, model)
        configuration = model.index_configuration
        logger = model.logger || nil

        b = evaluate_condition(configuration[:boost], model) if configuration[:boost]
        return b if b && b > 0
        if boost.class != Float || boost < 0
          logger.warn "The boost value has to be a float and posisive, but got #{boost}. Using default boost value." if logger
          return configuration[:default_boost]
        end
        boost
      end

      def condition_block?(condition)
        condition.respond_to?("call") && (condition.arity == 1 || condition.arity == -1)
      end

      def evaluate_condition(condition, field)
        case condition
          when Symbol then field.send(condition)
          when String then eval(condition, binding)
          else
            if condition_block?(condition)
              condition.call(field)
            else
              raise(
                ArgumentError,
                "The :if option has to be either a symbol, string (to be eval'ed), proc/method, or " +
                "class implementing a static validation method"
              )
            end
          end
      end

      # Sets a default value when value being set is nil.
      def set_value_if_nil(field_type)
        case field_type
          when "b", :boolean then                        return "false"
          when "s", "t", "t_ns", "t_ni", "d", "ngrams", "auto", "lc", "em", :date, :string, :text, :text_not_stored, :text_not_indexed, :ngrams, :autocomplete, :lowercase, :exact_match then return ""
          when "f", "rf", :float, :range_float then      return 0.00
          when "i", "ri", :integer, :range_integer then  return 0
          when "f_mv", "i_mv", "b_mv", "s_mv", "t_mv", "t_mv_ns", "d_mv", "rf_mv", "ri_mv", "ngrams_mv", "auto_mv", "lc_mv", "em_mv", "geo" then return []
          when :float_array, :integer_array, :boolean_array, :string_array, :date_array, :range_float_array, :range_integer_array, :ngrams_array, :text_array, :text_array_not_stored, :autocomplete_array, :lowercase_array, :exact_match_array, :geo then return []
        else
          return nil
        end
      end

    public # Making these methods public for anyone who wants to query the indexer directly

      # Method used by mostly all the ClassMethods when doing a search
      def parse_query(model, query=nil, options={}, models=nil)
        configuration = model.index_configuration

        valid_options = [:fields, :offset, :limit, :facets, :models, :results_format,
                         :order, :scores, :operator, :debug, :query_function, :include_deleted,
                         :view, :no_parsing, :force_reload, :timestamp]
         query_options = {}
         return if query.nil?

         # TODO: This should provide a warning instead of raising an error. Use log? or something else...
         # raise "Invalid parameters: #{(options.keys - valid_options).join(',')}" unless (options.keys - valid_options).empty?

         begin
           query_options[:start] = options[:offset]
           query_options[:rows] = options[:limit] || 100
           query_options[:debug_query] = options[:debug]

           # first steps on the facet parameter processing
           if options[:facets]
             query_options[:facets] = {}
             query_options[:facets][:limit] = -1  # TODO: make this configurable
             query_options[:facets][:sort] = :count if options[:facets][:sort]
             query_options[:facets][:mincount] = 0
             query_options[:facets][:mincount] = 1 if options[:facets][:zeros] == false
             query_options[:facets][:fields] = options[:facets][:fields].collect{|k| "#{k}_facet"} if options[:facets][:fields]
             query_options[:filter_queries] = replace_types(options[:facets][:browse].collect{|k| "#{k.sub!(/ *: */,"_facet:")}"}) if options[:facets][:browse]
             query_options[:facets][:queries] = replace_types(options[:facets][:query].collect{|k| "#{k.sub!(/ *: */,"_t:")}"}) if options[:facets][:query]
           end

           if models.nil?
             # TODO: use a filter query for type, allowing Solr to cache it individually
             models = "#{configuration[:type_field]}:\"#{model.index_type}\"^0.01"
             field_list = [configuration[:primary_key_field], configuration[:type_field]]
             if options[:fields]
               if options[:no_parsing]
                  field_list += options[:fields]
               else
                  field_list += replace_types(model, options[:fields].collect{|f|"#{f}_t"}, false)
               end
             end
           else
             field_list = ["id"]
           end

           query_options[:field_list] = field_list + ['id']
           unless query.empty?
             query = "(#{query.gsub(/ *: */,"_t:")}) AND #{models}" unless options[:no_parsing]
           else
             query = "#{models}"
           end

           order = options[:order]
           order = order.split(/\s*,\s*/).collect{|e| e.gsub(/\s+/,'_t ')  }.join(',') if order && !options[:no_parsing]

           query_options[:query] = options[:no_parsing] ? query : replace_types(model, [query])[0]
           if options[:order]
             # TODO: set the sort parameter instead of the old ;order. style.
             query_options[:query] << ';' << (options[:no_parsing] ? order : replace_types(model, [order], false)[0])
           end

           @connection.solr_execute(Solr::Request::Standard.new(query_options))
         rescue
           raise "There was a problem executing your search: #{$!}"
         end
      end

      # Parses the data returned from Solr
      def parse_results(model, solr_data, options = {})
        configuration = model.index_configuration

        results = {
          :docs => [],
          :total => 0
        }
        configuration[:format] = options[:format]
        configuration[:format] ||= :objects

        results.update(:facets => {'facet_fields' => []}) if options[:facets]

        return SearchResults.new(results) if solr_data.total_hits == 0

        configuration.update(options) if options.is_a?(Hash)

        ids = solr_data.hits.collect {|doc| doc["#{configuration[:primary_key_field]}"]}.flatten
        #conditions = [ "#{self.table_name}.#{primary_key} in (?)", ids ]

        if solr_data.data['debug'] and solr_data.data['debug']['explain']
          explain_data = solr_data.data['debug']['explain']
        end
        explain_data ||= {}

        if ids.size > 0
          case configuration[:format]
          when :objects
            options.reject!{|k,v|![:view, :force_reload, :include_deleted, :timestamp].include?(k)}
            options.merge({:bypass_index => true})
            result =  begin
                        reorder(model.find(ids, options), ids)
                      rescue
                        []
                      end
          when :ids
            result = ids
          else
            result = solr_data.hits.collect do |d|
              r = SolrResult.new(d, configuration[:primary_key_field], solr_data.total_hits, explain_data[d["id"]])
              r.properties_blurb_from_yaml(solr_data.data['properties_blurb'][r.id]) if (solr_data.data['properties_blurb'] && solr_data.data['properties_blurb'][r.id])
              r.blurb=(solr_data.data['blurbs'][r.id]) if solr_data.data['blurbs']
              r
            end
          end
        else
          result = []
        end

        results.update(:facets => solr_data.data['facet_counts']) if options[:facets]
        results.update(:debug => solr_data.data['debug'])

        results.update({:docs => result, :total => solr_data.total_hits, :max_score => solr_data.max_score})
        SearchResults.new(results)
      end

      # Reorders the instances keeping the order returned from Solr
      def reorder(things, ids)
        ordered_things = []
        ids.each do |id|
          found = things.find {|thing| thing.record_id.to_s == id.to_s}
          ordered_things << found if found
        end
        ordered_things
      end

      # Replaces the field types based on the types (if any) specified
      # on the acts_as_solr call
      def replace_types(model, strings, include_colon=true)
        configuration = model.index_configuration

        suffix = include_colon ? ":" : ""
        if configuration[:fields] && configuration[:fields].is_a?(Array)
          configuration[:fields].each do |index_field|

              field_type = get_field_type(index_field.field_type)
              field = "#{index_field.field_name.to_s}_#{field_type}#{suffix}"

                # Replace the type suffix only when the previous and next character is not a letter or other character
                # that is valid for a field name. That way, we ensure that we replace on a match of the field and not
                # only a partial match (e.g. name_t & ancestor_name_t... without the begin and end check, when we
                # replace name_t by name_s we would not only name_t but also the end of ancestor_name_t and the result
                # would be name_s & ancestor_name_s)
                strings.each_with_index do |s,i|
                  if suffix.empty?
                    strings[i] = s.gsub(/(^|[^a-z|A-Z|_|-|0-9])#{index_field.field_name.to_s}_t([^a-z|A-Z|_|-|0-9]|$)/) {|match| "#{$1}#{field}#{$2}"}
                  else
                    strings[i] = s.gsub(/(^|[^a-z|A-Z|_|-|0-9])#{index_field.field_name.to_s}_t#{suffix}/) {|match| "#{$1}#{field}"}
                  end
                end

          end
        end

        # fix the primary key type as well
        strings.each_with_index {|s,i| strings[i] = s.gsub(/pk_t#{suffix}/,"#{configuration[:primary_key_field]}#{suffix}") }

        # fix the general blob
        strings.each_with_index {|s,i| strings[i] = s.gsub(/blob_t#{suffix}/,"blob_t_mv#{suffix}") }

        # fix *
        strings.each_with_index {|s,i| strings[i] = s.gsub(/\*_t#{suffix}/,"*#{suffix}") }

        strings
      end

      def get_types(query)
        query.scan(/[^ ]+[:]/).uniq.collect{|s|s.chomp(':')} if query
      end


  end # module AdapterMethods

end # module Solr
