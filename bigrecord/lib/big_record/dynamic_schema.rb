module BigRecord
  module DynamicSchema

    def self.included(base) #:nodoc:
      super

      base.alias_method_chain :column_for_attribute, :dynamic_schema
      base.alias_method_chain :attributes_from_column_definition, :dynamic_schema
      base.alias_method_chain :inspect, :dynamic_schema
      base.alias_method_chain :define_read_methods, :dynamic_schema
    end

    # Stub of the callback for setting the dynamic columns. Override this to add dynamic columns
    def initialize_columns(options={})
    end

    # Create and add a dynamic column to this record
    def dynamic_column(name, type, options={})
      add_dynamic_column ConnectionAdapters::Column.new(name.to_s, type, options)
    end

    # Add an existing dynamic column to this record
    def add_dynamic_column(col)
      columns_hash[col.name] = col
      @columns_name= nil; @columns= nil #reset
      col
    end

    def columns_hash
      unless @columns_hash
        @columns_hash = self.class.columns_hash.dup
        initialize_columns
      end
      @columns_hash
    end

    def columns
      @columns ||= columns_hash.values
    end

    def column_names
      @column_names ||= columns_hash.keys
    end

    # Returns the column object for the named attribute.
    def column_for_attribute_with_dynamic_schema(name)
      self.columns_hash[name.to_s]
    end

    # Initializes the attributes array with keys matching the columns from the linked table and
    # the values matching the corresponding default value of that column, so
    # that a new instance, or one populated from a passed-in Hash, still has all the attributes
    # that instances loaded from the database would.
    def attributes_from_column_definition_with_dynamic_schema
      self.columns.inject({}) do |attributes, column|
        unless column.name == self.class.primary_key
          attributes[column.name] = column.default
        end
        attributes
      end
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect_with_dynamic_schema
      attributes_as_nice_string = self.column_names.collect { |name|
        if has_attribute?(name) || new_record?
          "#{name}: #{attribute_for_inspect(name)}"
        end
      }.compact.join(", ")
      "#<#{self.class} #{attributes_as_nice_string}>"
    end

    # Called on first read access to any given column and generates reader
    # methods for all columns in the columns_hash if
    # ActiveRecord::Base.generate_read_methods is set to true.
    def define_read_methods_with_dynamic_schema
      columns_hash.each do |name, column|
        unless respond_to_without_attributes?(name)
          define_read_method(name.to_sym, name, column)
        end

        unless respond_to_without_attributes?("#{name}?")
          define_question_method(name)
        end
      end
    end

  end
end
