
module BigIndex
  module Resource

    def self.included(model)
      model.extend ClassMethods if defined?(ClassMethods)
      model.const_set('Resource', self) unless model.const_defined?('Resource')

      model.class_eval do
        include InstanceMethods

        @indexed = true

        @configuration = {
          :fields => [],
          :additional_fields => nil,
          :exclude_fields => [],
          :auto_save => true,
          :auto_commit => true,
          :background => true,
          :include => nil,
          :facets => nil,
          :boost => nil,
          :if => "true"
        }

        class << self
          alias_method_chain :find, :index
        end
      end
    end

    alias model class

    module ClassMethods

      def default_repository_name
        Repository.default_name
      end

      def repository_name
        Repository.context.any? ? Repository.context.last.name : default_repository_name
      end

      def repository(name = nil)
        @repository ||
          if block_given?
            BigIndex.repository(name || repository_name) { |*block_args| yield(*block_args) }
          else
            BigIndex.repository(name || repository_name)
          end
      end

      def adapter
        repository.adapter
      end

      def configuration
        @configuration
      end

      def configuration=(config)
        @configuration = config
      end

      def indexed?
        if @indexed.nil?
          @indexed = false
          ancestors.each do |a|
            if a.respond_to?(:indexed?) and a.indexed?
              @indexed = true
              break
            end
          end
        end
        @indexed
      end

      def rebuild_index(options={}, finder_options={})
        adapter.rebuild_index(options, finder_options)
      end

      def process_index_batch(items, loop, options={})
        adapter.process_index_batch(items, loop, options={})
      end

      def index_view(name, columns)
        write_inheritable_attribute(:index_views_hash, read_inheritable_attribute(:index_views_hash) || default_index_views_hash)
        read_inheritable_attribute(:index_views_hash)[name] = columns
      end

      def index_views
        @index_views ||= index_views_hash.values
      end

      def index_view_names
        @index_view_names ||= index_views_hash.keys
      end

      def index_views_hash
        read_inheritable_attribute(:index_views_hash) || default_index_views_hash
      end

      def default_index_views_hash
        {:default => self.configuration[:fields]}
      end

      def set_unreturned_index_fields(fields)
        @unreturned_index_fields = fields
      end

      def unreturned_index_fields
        @unreturned_index_fields.to_a
      end

      def returned_index_fields
        unless @returned_index_fields
          fields = {}
          configuration[:solr_fields].each do |item|
            if item.is_a?(Hash)
              name = item.keys[0]
              fields.merge!(item) unless (unreturned_index_fields.find{|n| n == name} || item.values[0].to_s =~ /not_stored/)
            else
              fields[item] = :text unless unreturned_index_fields.find{|n| n == item}
            end
          end
          @returned_index_fields = fields.collect {|field, type| "#{field}_#{get_solr_field_type(type)}".to_sym}
          @returned_index_fields += [:score, :pk_s, :type_s_mv]
          @returned_index_fields.uniq!
        end
        @returned_index_fields
      end

      def index(field, options={}, &block)
        # Mixin the other methods only if the class is to be used for index, else keep it clean
        # unless self.respond_to?(:acting_as_solr) and acting_as_solr
        #   acts_as_solr :fields => [], :auto_commit => true # (ENV['RAILS_ENV']=='test')
        # end

        add_index_field(field, block)

        field_name = field.is_a?(Hash) ? field.keys[0] : field
        finder_name = options[:finder_name] || field_name

        # default finder: exact match on the index name
        #define_finder finder_name, [{:field => field, :weight => 1}]
      end

      def add_index_field(field, block)
        if self.configuration[:fields]
          unless self.configuration[:fields].include?(field)
            self.configuration[:fields] << field
          else
            return
          end
        else
          self.configuration[:fields] = [field]
        end

        field_name = field.is_a?(Hash) ? field.keys[0] : field
      end

      def find_with_index(*args)
        options = args.extract_options!
        unless options[:bypass_index]
          validate_index_find_options(options)
          case args.first
            when :first then find_every_by_index(options.merge({:limit => 1})).first
            when :all   then find_every_by_index(options)
            else             find_from_ids(args, options) #TODO: implement in solr
          end
        else
          options.delete(:bypass_index)
          find_without_index(*(args + [options]))
        end
      end

      def find_every_by_index(options)
        # Construct the query. First add the type information.
        #query = "type:#{self.name}^4 "
        query =""

        # set default operator
        options[:operator] ||= :or

        # First add the conditions predicates
        conditions = options[:conditions]
        if conditions.is_a?(String)
          query << conditions
        elsif conditions.is_a?(Array) and !conditions.empty?
          nb_conditions = conditions.size - 1
          i = 0
          query << conditions[0].gsub(/\?/) do |c|
            i += 1
            raise ArgumentError, "Missing condition argument" unless i <= nb_conditions
            "#{conditions[i]}"
          end
        elsif conditions.is_a?(Hash) and !conditions.empty?
          conditions.each do |k, v|
            query << "#{k}:#{v} "
          end
        end

        fields =
          if options[:fields]
            options[:fields]
          else
            fields = options[:view] ? index_views_hash[options[:view]] : index_views_hash[:default]
            fields ||= []
          end

        if options[:source] == :index
          adapter.find_values_by_index(query, :offset    =>options[:offset],
                                      :order    => options[:order],
                                      :limit    => options[:limit],
                                      :fields   => fields,
                                      :operator => options[:operator],
                                      :debug    => options[:debug])
        else
          adapter.find_by_index(query, :offset   => options[:offset],
                              :order    => options[:order],
                              :limit    => options[:limit],
                              :operator => options[:operator])
        end
      end

      INDEX_FIND_OPTIONS = [ :source, :offset, :limit, :conditions, :order, :group, :fields, :debug, :view ]

      def validate_index_find_options(options) #:nodoc:
        options.assert_valid_keys(INDEX_FIND_OPTIONS)
      end

    end

    module InstanceMethods

      def indexed?
        self.class.indexed?
      end

    end

  end # module Resource
end # module BigIndex
