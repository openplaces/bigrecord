module Solr

  module AdapterMethods

    private

      def solr_add(add_xml)
        @connection.solr_execute(Solr::Request::AddDocument.new(add_xml))
      end

      def solr_delete(solr_ids)
        @connection.solr_execute(Solr::Request::Delete.new(:id => solr_ids))
      end

      def solr_commit
        @connection.solr_execute(Solr::Request::Commit.new)
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
          field_name = field
          field_type = configuration[:facets] && configuration[:facets].include?(field) ? :facet : :text
          field_boost= configuration[:default_boost]

          if field.is_a?(Hash)
            field_name = field.keys.pop
            if field.values.pop.respond_to?(:each_pair)
              attributes = field.values.pop
              field_type = get_field_type(attributes[:type]) if attributes[:type]
              field_boost= attributes[:boost] if attributes[:boost]
            else
              field_type = get_field_type(field.values.pop)
              field_boost= field[:boost] if field[:boost]
            end
          end
          value = model.send("#{field_name}_for_index")
          value = set_value_if_nil(field_type) if value.to_s == ""

          # add the field to the document, but only if it's not the id field
          # or the type field (from single table inheritance), since these
          # fields have already been added above.
          if field_name.to_s != model.class.primary_key and field_name.to_s != "type"
            suffix = get_field_type(field_type)
            # This next line ensures that e.g. nil dates are excluded from the
            # document, since they choke Solr. Also ignores e.g. empty strings,
            # but these can't be searched for anyway:
            # http://www.mail-archive.com/solr-dev@lucene.apache.org/msg05423.html
            next if value.nil? || value.to_s.strip.empty?
            [value].flatten.each do |v|
              v = set_value_if_nil(suffix) if value.to_s == ""
              field = Solr::Field.new("#{field_name}_#{suffix}" => ERB::Util.html_escape(v.to_s))
              field.boost = validate_boost(field_boost, model)
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

      class SolrResult
       #Dependencies.mark_for_unload self

        attr_accessor :total_hits
        attr_accessor :type
        attr_accessor :score
        attr_accessor :explain
        attr_accessor :index_id
        attr_accessor :solr_types
        attr_accessor :blurb
        attr_accessor :properties_blurb
        attr_accessor :web_documents

        def initialize(h, primary_key, total_hits, explain)
          @attributes = {}
          h.each do |k, v|
            case k
              when "score"      then @score = v
              when "type_s_mv"  then @solr_types = v
              when "pk_s"       then @attributes["id"] ||= v
              when "id"
                @index_id = v
                index_id_split = @index_id.split(":", 2)
                @attributes["id"] ||= index_id_split[1]
                @type = index_id_split[0]
              else
                # It's a normal case. Remove the suffix to make the result cleaner.
                if k.size >= 3 and k[-3..-1] == "_mv"
                  k =~ /(.*)_.*_mv$/
                elsif k.size >= 3 and k[-3..-1] == "_ni"
                  k =~ /(.*)_.*_ni$/
                else
                  k =~ /(.*)_.*$/
                end
                @attributes[$1 || k] = v
            end
          end
          @total_hits = total_hits
          @explain = explain

          if @solr_types
            @solr_types.each do |t|
              # add the shared behavior of the associated model class
              self.extend(eval("#{t}::SharedMethods")) rescue nil

              # add the shared behavior on Solr object
              self.extend(eval("#{t}::SolrMethods")) rescue nil
            end
          end
        end

        def attributes
          @attributes.dup
        end

        # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
        # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
        # (Alias for the protected read_attribute method).
        def [](attr_name)
          @attributes[attr_name.to_s]
        end

        # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
        # (Alias for the protected write_attribute method).
        def []=(attr_name, value)
          @attributes[attr_name.to_s] = value
        end

        def id
          self['id']
        end

        def updated_at
          Time.parse(self["updated_at"]) if self["updated_at"]
        end

        def created_at
          Time.parse(self["updated_at"]) if self["updated_at"]
        end

        def properties_blurb_from_yaml(yaml_string)
          yaml_loaded = YAML::load(yaml_string)
          @properties_blurb = (yaml_loaded.nil? || yaml_loaded.empty? ? nil : yaml_loaded.collect{|b|[b.shift, b]})
        end

        def method_missing(method_id, *arguments)
          unless !arguments.empty?
            self[method_id.to_s]
          end
        end

        # convert the lightweight solr result into a real object
        def real(options={})
          @real ||= self.type.constantize.find(self.id, options)
        end

        def delete_from_index
          self.type.constantize.solr_delete(self.index_id)
          self.type.constantize.solr_commit
        end

        def ==(comparison_object)
          comparison_object && self.id == comparison_object.id
        end

        # Delegates to ==
        def eql?(comparison_object)
          self == (comparison_object)
        end

        # Delegates to id in order to allow two records of the same type and id to work with something like:
        #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
        def hash
          id.hash
        end

        def to_s
          self.id.to_s
        end

        def logger
          BigRecord::Base.logger
        end

      end

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

      # Method used by mostly all the ClassMethods when doing a search
      def parse_query(model, query=nil, options={}, models=nil)
        configuration = model.index_configuration

        valid_options = [:fields, :offset, :limit, :facets, :models, :results_format,
                         :order, :scores, :operator, :debug, :query_function, :include_deleted,
                         :view, :no_parsing, :force_reload, :timestamp]
         query_options = {}
         return if query.nil?
         raise "Invalid parameters: #{(options.keys - valid_options).join(',')}" unless (options.keys - valid_options).empty?
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
                  field_list += replace_types(options[:fields].collect{|f|"#{f}_t"}, false)
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
             query_options[:query] << ';' << (options[:no_parsing] ? order : replace_types([order], false)[0])
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
              result = reorder(model.find_all_by_id(ids, options), ids)
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

        # FIXME: this is stupid and should be removed... it's only required for find_articles
        results.update(:exact_match => solr_data.exact_match) if solr_data.respond_to?(:exact_match)

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
          configuration[:fields].each do |solr_field|
            field_type = get_field_type(:text)
            if solr_field.is_a?(Hash)
              solr_field.each do |name,value|
                if value.respond_to?(:each_pair)
                  field_type = get_field_type(value[:type]) if value[:type]
                else
                  field_type = get_field_type(value)
                end
                field = "#{name.to_s}_#{field_type}#{suffix}"

                # Replace the type suffix only when the previous and next character is not a letter or other character
                # that is valid for a field name. That way, we ensure that we replace on a match of the field and not
                # only a partial match (e.g. name_t & ancestor_name_t... without the begin and end check, when we
                # replace name_t by name_s we would not only name_t but also the end of ancestor_name_t and the result
                # would be name_s & ancestor_name_s)
                strings.each_with_index do |s,i|
                  if suffix.empty?
                    strings[i] = s.gsub(/(^|[^a-z|A-Z|_|-|0-9])#{name.to_s}_t([^a-z|A-Z|_|-|0-9]|$)/) {|match| "#{$1}#{field}#{$2}"}
                  else
                    strings[i] = s.gsub(/(^|[^a-z|A-Z|_|-|0-9])#{name.to_s}_t#{suffix}/) {|match| "#{$1}#{field}"}
                  end
                end
  #              strings.each_with_index {|s,i| strings[i] = s.gsub(/#{name.to_s}_t#{suffix}/,field) }
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
