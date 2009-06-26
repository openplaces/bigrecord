module ActsAsSolr #:nodoc:

  module ActiveRecordClassMethods
    
    def find(*args)
      options = args.extract_options!
      validate_find_options(options)
#      set_readonly_option!(options)
     
      if options[:source] && options[:source].to_s == 'index'
        case args.first
          when :first then find_every_by_solr(options.merge({:limit => 1})).first
          when :all   then find_every_by_solr(options)
          else             find_from_ids(args, options) #TODO: implement in solr
        end
      else
       case args.first
         when :first then find_initial(options)
         when :last  then find_last(options)
         when :all   then find_every(options)
         else             find_from_ids(args, options)
       end 
      end
    end
  
    
    VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset,
                               :order, :select, :readonly, :group, :from, :lock,
                               :source,:fields,:debug,:view,:include_deleted,:stop_row]  # duck taped
    def validate_find_options(options) #:nodoc:
      options.assert_valid_keys(VALID_FIND_OPTIONS)
    end
    
    def find_every_by_solr(options)
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
        find_values_by_solr(query, :offset    =>options[:offset], 
                                    :order    => options[:order], 
                                    :limit    => options[:limit], 
                                    :fields   => fields, 
                                    :operator => options[:operator],
                                    :debug    => options[:debug]).docs
      else
        find_by_solr(query, :offset   => options[:offset], 
                            :order    => options[:order], 
                            :limit    => options[:limit], 
                            :operator => options[:operator]).docs
      end
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
 
  end
  
end
