module Solr

  module AdapterMethods

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
            self.extend(eval("#{t}::IndexMethods")) rescue nil
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
        begin
          BigRecord::Base.logger || ActiveRecord::Base.logger
        rescue
          nil
        end
      end

    end

  end # module AdapterMethods

end # module Solr