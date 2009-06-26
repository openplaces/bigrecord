module ActsAsSolr #:nodoc:
  
  module InstanceMethods
    
    def acting_as_solr
      self.class.acting_as_solr
    end

    def configuration
      self.class.configuration
    end

    def configuration=(conf)
      self.class.configuration = conf
    end

    def solr_configuration
      self.class.solr_configuration
    end

    def solr_configuration=(conf)
      self.class.solr_configuration = conf
    end

    # Solr id is <class.name>:<id> to be unique across all models
    def solr_id
      classname = self.class.solr_type
      "#{classname}:#{record_id(self)}"
    end

    # saves to the Solr index
    def solr_save
      if !self.class.solr_disabled && configuration[:if] && evaluate_condition(configuration[:if], self)
        solr_add to_solr_doc
        solr_commit if configuration[:auto_commit]
      end
      true
    end

    # remove from index
    def solr_destroy
      
      solr_delete solr_id
      solr_delete ":#{record_id(self)}"
      solr_commit if configuration[:auto_commit]

      true
    end

    def solr_execute(request)
      self.class.solr_execute(request, solr_shard_url)
    end
    
    def solr_shard_url
      self.class.shard_url_for(self.id)
    end

    def all_classes_for_solr
      all_classes = []
      current_class = self.class
      base_class = current_class.base_class
      while current_class != base_class
        all_classes << current_class
        current_class = current_class.superclass
      end
      all_classes << base_class
      return all_classes
    end

    # convert instance to Solr document
    def to_solr_doc
      doc = Solr::Document.new
      doc.boost = validate_boost(configuration[:boost]) if configuration[:boost]
      
      
      doc << {:id => solr_id,
              solr_configuration[:type_field] => self.all_classes_for_solr,
              solr_configuration[:primary_key_field] => record_id(self).to_s}

      # iterate through the fields and add them to the document,
      configuration[:solr_fields].each do |field|
        field_name = field
        field_type = configuration[:facets] && configuration[:facets].include?(field) ? :facet : :text
        field_boost= solr_configuration[:default_boost]

        if field.is_a?(Hash)
          field_name = field.keys.pop
          if field.values.pop.respond_to?(:each_pair)
            attributes = field.values.pop
            field_type = get_solr_field_type(attributes[:type]) if attributes[:type]
            field_boost= attributes[:boost] if attributes[:boost]
          else
            field_type = get_solr_field_type(field.values.pop)
            field_boost= field[:boost] if field[:boost]
          end
        end
        
        # add the field to the document, but only if it's not the id field
        # or the type field (from single table inheritance), since these
        # fields have already been added above.
        if field_name.to_s != self.class.primary_key and field_name.to_s != "type"
          suffix = get_solr_field_type(field_type)
          
          begin
            f = Solr::Field.new
            f.name = "#{field_name}_#{suffix}"
          
            self.send("#{field_name}_for_solr", f)

            f.values = set_value_if_nil(suffix) if f.values.to_s == ""
            [f.values].flatten.each do |v|
              # the boost can be specified for each individual field
              value = v
              boost = field_boost
              if v.respond_to?(:each_pair)
                value = v.keys.first
                boost = v.values.first
              end
              value = set_value_if_nil(suffix) if value.to_s == ""
              field = Solr::FieldEntry.new(f.name => value.to_s)
              field.boost = validate_boost(boost)
              doc << field
            end
          rescue Exception => ex
            logger.error "Failed to index the field #{self.class.name}.#{field_name} for id=#{self.id}. Got this exception:"
            logger.error ex.message
            logger.error ex.backtrace.join("\n")
          end
        end
      end
      
      add_includes(doc) if configuration[:include]
      return doc
    end
    
    private
    def add_includes(doc)
      if configuration[:include].is_a?(Array)
        configuration[:include].each do |association|
          data = ""
          klass = association.to_s.singularize
          case self.class.reflect_on_association(association).macro
          when :has_many, :has_and_belongs_to_many
            records = self.send(association).to_a
            unless records.empty?
              records.each{|r| data << r.attributes.inject([]){|k,v| k << "#{v.first}=#{v.last}"}.join(" ")}
              doc["#{klass}_t"] = data
            end
          when :has_one, :belongs_to
            record = self.send(association)
            unless record.nil?
              data = record.attributes.inject([]){|k,v| k << "#{v.first}=#{v.last}"}.join(" ")
              doc["#{klass}_t"] = data
            end
          end
        end
      end
    end
    
    def validate_boost(boost)
      b = evaluate_condition(configuration[:boost], self) if configuration[:boost]
      return b if b && b > 0
      if boost.class != Float || boost < 0
        logger.warn "The boost value has to be a float and posisive, but got #{boost}. Using default boost value."
        return solr_configuration[:default_boost]
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
    
  end
end
