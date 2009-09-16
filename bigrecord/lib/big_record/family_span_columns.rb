# Replace the anonymous classes
module BigRecord
  module FamilySpanColumns

    def self.included(base) #:nodoc:
      super
      base.alias_method_chain :column_for_attribute, :family_span_columns
      base.alias_method_chain :attributes_from_column_definition, :family_span_columns

      base.extend(ClassMethods)
      base.class_eval do
        class << self
          alias_method_chain :alias_attribute, :family_span_columns
        end
      end
    end

    module ClassMethods

      # Returns the list of columns that are not spanned on a whole family
      def simple_columns
        columns.select{|c|!c.family?}
      end

      # Returns the list of columns that are spanned on a whole family
      def family_columns
        columns.select{|c|c.family?}
      end

      # Define aliases to the fully qualified attributes
      def alias_attribute_with_family_span_columns(alias_name, fully_qualified_name)
        # when it's a single column everything's normal but when it's a
        # column family then this actually add accessors for the whole family
        alias_attribute_without_family_span_columns(alias_name, fully_qualified_name)

        # fully_qualified_name ends with ':' => consider it a family span column
        if fully_qualified_name.ends_with?(":")
          # add the accessors for the individual columns
          self.class_eval <<-EOF
            def #{alias_name}(column_key=nil)
              if column_key
                read_attribute("#{fully_qualified_name}\#{column_key}")
              else
                read_family_attributes("#{fully_qualified_name}")
              end
            end
            def set_#{alias_name}(column_key, value)
              write_attribute("#{fully_qualified_name}\#{column_key}", value)
            end
          EOF
        end
      end
    end

    # Returns the list of columns that are not spanned on a whole family
    def simple_columns
      columns.select{|c|!c.family?}
    end

    # Returns the column object for the named attribute.
    def column_for_attribute_with_family_span_columns(name)
      name = name.to_s

      # ignore methods '=' and '?' (e.g. 'normalized_srf_ief:231=')
      return if name =~ /=|\?$/

      column = self.columns_hash[name]
      unless column
        family = BigRecord::ConnectionAdapters::Column.extract_family(name)
        column = self.columns_hash[family] if family
      end
      column
    end

    # Initializes the attributes array with keys matching the columns from the linked table and
    # the values matching the corresponding default value of that column, so
    # that a new instance, or one populated from a passed-in Hash, still has all the attributes
    # that instances loaded from the database would.
    def attributes_from_column_definition_with_family_span_columns
      self.simple_columns.inject({}) do |attributes, column|
        unless column.name == self.class.primary_key or column.family?
          attributes[column.name] = column.default
        end
        attributes
      end
    end

  end
end
