module BigRecord
  class BigRecordError < StandardError #:nodoc:
  end
  class SubclassNotFound < BigRecordError #:nodoc:
  end
  class AssociationTypeMismatch < BigRecordError #:nodoc:
  end
  class WrongAttributeDataType < BigRecordError #:nodoc:
  end
  class AttributeMissing < BigRecordError #:nodoc:
  end
  class UnknownAttribute < BigRecordError #:nodoc:
  end
  class AdapterNotSpecified < BigRecordError # :nodoc:
  end
  class AdapterNotFound < BigRecordError # :nodoc:
  end
  class ConnectionNotEstablished < BigRecordError #:nodoc:
  end
  class ConnectionFailed < BigRecordError #:nodoc:
  end
  class RecordNotFound < BigRecordError #:nodoc:
  end
  class RecordNotSaved < BigRecordError #:nodoc:
  end
  class StatementInvalid < BigRecordError #:nodoc:
  end
  class PreparedStatementInvalid < BigRecordError #:nodoc:
  end
  class StaleObjectError < BigRecordError #:nodoc:
  end
  class ConfigurationError < StandardError #:nodoc:
  end
  class ReadOnlyRecord < StandardError #:nodoc:
  end
  class NotImplemented < BigRecordError #:nodoc:
  end
  class ColumnNotFound < BigRecordError #:nodoc:
  end
  class AttributeAssignmentError < BigRecordError #:nodoc:
    attr_reader :exception, :attribute
    def initialize(message, exception, attribute)
      @exception = exception
      @attribute = attribute
      @message = message
    end
  end
  class MultiparameterAssignmentErrors < BigRecordError #:nodoc:
    attr_reader :errors
    def initialize(errors)
      @errors = errors
    end
  end

  class AbstractBase
    require 'rubygems'
    require 'uuidtools'

    # Accepts a logger conforming to the interface of Log4r or the default Ruby 1.8+ Logger class, which is then passed
    # on to any new database connections made and which can be retrieved on both a class and instance level by calling +logger+.
    cattr_accessor :logger, :instance_writer => false

    # Constants for special characters in generated IDs. An ID might then look
    # like this: 'United_States-Hawaii-Oahu-Honolulu-b9cef848-a4e0-11dc-a7ba-0018f3137ea8'
    ID_FIELD_SEPARATOR = '-'
    ID_WHITE_SPACE_CHAR = '_'

    def self.inherited(child) #:nodoc:
      @@subclasses[self] ||= []
      @@subclasses[self] << child
      child.set_table_name child.name.tableize if child.superclass == BigRecord::Base
      super
    end

    def self.reset_subclasses #:nodoc:
      nonreloadables = []
      subclasses.each do |klass|
        unless Dependencies.autoloaded? klass
          nonreloadables << klass
          next
        end
        klass.instance_variables.each { |var| klass.send(:remove_instance_variable, var) }
        klass.instance_methods(false).each { |m| klass.send :undef_method, m }
      end
      @@subclasses = {}
      nonreloadables.each { |klass| (@@subclasses[klass.superclass] ||= []) << klass }
    end

    @@subclasses = {}

    def self.store_primary_key?
      false
    end

    cattr_accessor :configurations, :instance_writer => false
    @@configurations = {}

    # Accessor for the name of the prefix string to prepend to every table name. So if set to "basecamp_", all
    # table names will be named like "basecamp_projects", "basecamp_people", etc. This is a convenient way of creating a namespace
    # for tables in a shared database. By default, the prefix is the empty string.
    cattr_accessor :table_name_prefix, :instance_writer => false
    @@table_name_prefix = ""

    # Works like +table_name_prefix+, but appends instead of prepends (set to "_basecamp" gives "projects_basecamp",
    # "people_basecamp"). By default, the suffix is the empty string.
    cattr_accessor :table_name_suffix, :instance_writer => false
    @@table_name_suffix = ""

    # Indicates whether table names should be the pluralized versions of the corresponding class names.
    # If true, the default table name for a +Product+ class will be +products+. If false, it would just be +product+.
    # See table_name for the full rules on table/class naming. This is true, by default.
    cattr_accessor :pluralize_table_names, :instance_writer => false
    @@pluralize_table_names = true

    # Determines whether or not to use ANSI codes to colorize the logging statements committed by the connection adapter. These colors
    # make it much easier to overview things during debugging (when used through a reader like +tail+ and on a black background), but
    # may complicate matters if you use software like syslog. This is true, by default.
    cattr_accessor :colorize_logging, :instance_writer => false
    @@colorize_logging = true

    # Determines whether to use Time.local (using :local) or Time.utc (using :utc) when pulling dates and times from the database.
    # This is set to :local by default.
    cattr_accessor :default_timezone, :instance_writer => false
    @@default_timezone = :local

    # Determines whether to speed up access by generating optimized reader
    # methods to avoid expensive calls to method_missing when accessing
    # attributes by name. You might want to set this to false in development
    # mode, because the methods would be regenerated on each request.
    cattr_accessor :generate_read_methods, :instance_writer => false
    @@generate_read_methods = false

    # Determines whether or not to use a connection for each thread, or a single shared connection for all threads.
    # Defaults to false. Set to true if you're writing a threaded application.
    cattr_accessor :allow_concurrency, :instance_writer => false
    @@allow_concurrency = false

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    #
    # @param [Hash] Optional hash argument consisting of keys that match the names of the columns, and their values.
    def initialize(attrs = nil)
      preinitialize(attrs)
      @attributes = attributes_from_column_definition
      self.attributes = attrs unless attrs.nil?
    end

    # Callback method meant to be overriden by subclasses if they need to preload some
    # attributes before initializing the record. (usefull when using a meta model where
    # the list of columns depends on the value of an attribute)
    def preinitialize(attrs = nil)
      @attributes = {}
    end

    def deserialize(attrs = nil)
    end

    # Safe version of attributes= so that objects can be instantiated even
    # if columns are removed.
    #
    # @param [Hash] Attribute hash consisting of the column name and their values.
    # @param [true, false] Pass the attributes hash through {#remove_attributes_protected_from_mass_assignment}
    def safe_attributes=(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!

      multi_parameter_attributes = []
      attributes = remove_attributes_protected_from_mass_assignment(attributes) if guard_protected_attributes

      attributes.each do |k, v|
        begin
          k.include?("(") ? multi_parameter_attributes << [ k, v ] : send(k + "=", v)
        rescue
          logger.debug "#{__FILE__}:#{__LINE__} Warning! Ignoring attribute '#{k}' because it doesn't exist anymore"
        end
      end

      begin
        assign_multiparameter_attributes(multi_parameter_attributes)
      rescue
        logger.debug "#{__FILE__}:#{__LINE__} Warning! Ignoring multiparameter attributes because some don't exist anymore"
      end
    end

    # A model instance's primary key is always available as model.id
    # whether you name it the default 'id' or set it to something else.
    def id
      attr_name = self.class.primary_key
      c = column_for_attribute(attr_name)
      define_read_method(:id, attr_name, c) if self.class.generate_read_methods
      read_attribute(attr_name)
    end

    # Default to_s method that just returns invokes the {#id} method
    #
    # @return [String] The row identifier/id of the record
    def to_s
      id
    end

    # Get the attributes hash of the object.
    #
    # @return [Hash] a duplicated attributes hash
    def attributes()
      @attributes.dup
    end

    # Reloads the attributes of this object from the database.
    # The optional options argument is passed to find when reloading so you
    # may do e.g. record.reload(:lock => true) to reload the same record with
    # an exclusive row lock.
    #
    # @return Itself with reloaded attributes.
    def reload(options = nil)
      @attributes.update(self.class.find(self.id, options).instance_variable_get('@attributes'))
      self
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    # (Alias for the protected read_attribute method).
    def [](attr_name)
      read_attribute(attr_name)
    end

    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
    # (Alias for the protected write_attribute method).
    def []=(attr_name, value)
      write_attribute(attr_name, value)
    end

    # Allows you to set all the attributes at once by passing in a hash with keys
    # matching the attribute names (which again matches the column names). Sensitive attributes can be protected
    # from this form of mass-assignment by using the +attr_protected+ macro. Or you can alternatively
    # specify which attributes *can* be accessed in with the +attr_accessible+ macro. Then all the
    # attributes not included in that won't be allowed to be mass-assigned.
    def attributes=(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!

      multi_parameter_attributes = []
      attributes = remove_attributes_protected_from_mass_assignment(attributes) if guard_protected_attributes

      attributes.each do |k, v|
        k.include?("(") ? multi_parameter_attributes << [ k, v ] : send(k + "=", v)
      end

      assign_multiparameter_attributes(multi_parameter_attributes)
    end

    def all_attributes_loaded=(loaded)
      @all_attributes_loaded = loaded
    end

    def all_attributes_loaded?
      @all_attributes_loaded
    end

    # Format attributes nicely for inspect.
    def attribute_for_inspect(attr_name)
      value = read_attribute(attr_name)

      if value.is_a?(String) && value.length > 50
        "#{value[0..50]}...".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      else
        value.inspect
      end
    end

    # Returns true if the specified +attribute+ has been set by the user or by a database load and is neither
    # nil nor empty? (the latter only applies to objects that respond to empty?, most notably Strings).
    #
    # @return [String, Symbol] Name of an attribute.
    # @return [true,false] Whether that attribute exists.
    def attribute_present?(attribute)
      value = read_attribute(attribute)
      !value.blank? or value == 0
    end

    # Returns true if the given attribute is in the attributes hash
    #
    # @return [String, Symbol] Name of an attribute.
    # @return [true,false] Whether that attribute exists in the attributes hash.
    def has_attribute?(attr_name)
      @attributes.has_key?(attr_name.to_s)
    end

    # Returns an array of names for the attributes available on this object sorted alphabetically.
    def attribute_names
      @attributes.keys.sort
    end

    def human_attribute_name(attribute_key)
      self.class.human_attribute_name(attribute_key)
    end

    # Overridden by FamilySpanColumns
    # Returns the column object for the named attribute.
    def column_for_attribute(name)
      self.class.columns_hash[name.to_s]
    end

    # Returns true if the +comparison_object+ is the same object, or is of the same type and has the same id.
    def ==(comparison_object)
      comparison_object.equal?(self) ||
        (comparison_object.instance_of?(self.class) &&
          comparison_object.id == id &&
          !comparison_object.new_record?)
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

    # For checking respond_to? without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A Person object with a name attribute can ask person.respond_to?("name"), person.respond_to?("name="), and
    # person.respond_to?("name?") which will all return true.
    def respond_to?(method, include_priv = false)
      if @attributes.nil?
        return super
      elsif attr_name = self.class.column_methods_hash[method.to_sym]
        return true if @attributes.include?(attr_name) || attr_name == self.class.primary_key
        return false if self.class.read_methods.include?(attr_name)
      elsif @attributes.include?(method.to_s)
        return true
      elsif md = self.class.match_attribute_method?(method.to_s)
        return true if @attributes.include?(md.pre_match)
      end
      # super must be called at the end of the method, because the inherited respond_to?
      # would return true for generated readers, even if the attribute wasn't present
      super
    end

    # Just freeze the attributes hash, such that associations are still accessible even on destroyed records.
    def freeze
      @attributes.freeze; self
    end

    # Checks whether the object has had its attributes hash frozen.
    #
    # @return [true,false]
    def frozen?
      @attributes.frozen?
    end

    def quoted_id #:nodoc:
      quote_value(id, column_for_attribute(self.class.primary_key))
    end

    # Sets the primary ID.
    def id=(value)
      write_attribute(self.class.primary_key, value)
    end

    # Returns true if this object hasn't been saved yet -- that is, a record for the object doesn't exist yet.
    def new_record?
      false
    end

    # Method that saves the BigRecord object into the database. It will do one of two things:
    # * If no record currently exists: Creates a new record with values matching those of the object attributes.
    # * If a record already exist: Updates the record with values matching those of the object attributes.
    def save
      raise NotImplemented
    end

    # Attempts to save the record, but instead of just returning false if it couldn't happen, it raises a
    # RecordNotSaved exception
    def save!
      raise NotImplemented
    end

    # Deletes the record in the database and freezes this instance to reflect that no changes should
    # be made (since they can't be persisted).
    def destroy
      raise NotImplemented
    end

    # Updates a single attribute and saves the record. This is especially useful for boolean flags on existing records.
    # Note: This method is overwritten by the Validation module that'll make sure that updates made with this method
    # doesn't get subjected to validation checks. Hence, attributes can be updated even if the full object isn't valid.
    def update_attribute(name, value)
      raise NotImplemented
    end

    # Updates all the attributes from the passed-in Hash and saves the record. If the object is invalid, the saving will
    # fail and false will be returned.
    def update_attributes(attributes)
      raise NotImplemented
    end

    # Updates an object just like Base.update_attributes but calls save! instead of save so an exception is raised if the record is invalid.
    def update_attributes!(attributes)
      raise NotImplemented
    end

    # Returns the connection adapter of the current session.
    def connection
      self.class.connection
    end

    # Records loaded through joins with piggy-back attributes will be marked as read only as they cannot be saved and return true to this query.
    def readonly?
      @readonly == true
    end

    # Sets the record to be readonly
    def readonly! #:nodoc:
      @readonly = true
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect
      attributes_as_nice_string = self.class.column_names.collect { |name|
        if has_attribute?(name) || new_record?
          "#{name}: #{attribute_for_inspect(name)}"
        end
      }.compact.join(", ")
      "#<#{self.class} #{attributes_as_nice_string}>"
    end

  protected

    def clone_in_persistence_format
      validate_attributes_schema

      data = {}

      # normalized attributes without the id
      @attributes.keys.each do |key|
        next if !self.class.store_primary_key? and (key == self.class.primary_key)
        value = read_attribute(key)
        if value.kind_of?(Embedded)
          data[key] = value.clone_in_persistence_format
        elsif value.is_a?(Array)
          data[key] = value.collect do |e|
            if e.kind_of?(Embedded)
              e.clone_in_persistence_format
            else
              e
            end
          end
        else
          data[key] = value
        end
      end
      data
    end

    # Validate the type of the values in the attributes hash
    def validate_attributes_schema
      @attributes.keys.each do |key|
        value = read_attribute(key)
        next unless value
        # type validation
        if (column = column_for_attribute(key)) and !key.ends_with?(":")
          if column.collection?
            unless value.is_a?(Array)
              raise WrongAttributeDataType, "#{human_attribute_name(column.name)} has the wrong type. Expected collection of #{column.klass}. Record is #{value.class}"
            end
            value.each do |v|
              validate_attribute_type(v, column)
            end
          else
            validate_attribute_type(value, column)
          end
        else
          # Don't save attributes set in a previous schema version
          @attributes.delete(key)
        end
      end
    end

    def validate_attribute_type(value, column)
      unless (value == nil) or value.kind_of?(column.klass)
        raise WrongAttributeDataType, "#{human_attribute_name(column.name)} has the wrong type. Expected #{column.klass}. Record is #{value.class}"
      end
    end

    # Generate a new id with the UUIDTools library.
    # Override this method to use another id generator.
    def generate_new_id
      UUIDTools::UUID.random_create.to_s
    end

    # Initializes the attributes array with keys matching the columns from the linked table and
    # the values matching the corresponding default value of that column, so
    # that a new instance, or one populated from a passed-in Hash, still has all the attributes
    # that instances loaded from the database would.
    def attributes_from_column_definition
      self.class.columns.inject({}) do |attributes, column|
        unless column.name == self.class.primary_key
          attributes[column.name] = column.default
        end
        attributes
      end
    end

    # Instantiates objects for all attribute classes that needs more than one constructor parameter. This is done
    # by calling new on the column type or aggregation type (through composed_of) object with these parameters.
    # So having the pairs written_on(1) = "2004", written_on(2) = "6", written_on(3) = "24", will instantiate
    # written_on (a date type) with Date.new("2004", "6", "24"). You can also specify a typecast character in the
    # parentheses to have the parameters typecasted before they're used in the constructor. Use i for Fixnum, f for Float,
    # s for String, and a for Array. If all the values for a given attribute are empty, the attribute will be set to nil.
    def assign_multiparameter_attributes(pairs)
      execute_callstack_for_multiparameter_attributes(
        extract_callstack_for_multiparameter_attributes(pairs)
      )
    end

    # Includes an ugly hack for Time.local instead of Time.new because the latter is reserved by Time itself.
    def execute_callstack_for_multiparameter_attributes(callstack)
      errors = []
      callstack.each do |name, values|
        # TODO: handle aggregation reflections
#        klass = (self.class.reflect_on_aggregation(name.to_sym) || column_for_attribute(name)).klass
        column = column_for_attribute(name)
        if column
          klass = column.klass

          # Ugly fix for time selectors so that when any value is invalid the value is considered invalid, hence nil
          if values.empty? or (column.type == :time and !values[-2..-1].all?) or ([:date, :datetime].include?(column.type) and !values.all?)
            send(name + "=", nil)
          else
            # End of the ugly time fix...
            values = [2000, 1, 1, values[-2], values[-1]] if column.type == :time and !values[0..2].all?
            begin
              send(name + "=", Time == klass ? (@@default_timezone == :utc ? klass.utc(*values) : klass.local(*values)) : klass.new(*values))
            rescue => ex
              errors << AttributeAssignmentError.new("error on assignment #{values.inspect} to #{name}", ex, name)
            end
          end
        end
      end
      unless errors.empty?
        raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes"
      end
    end

    def extract_callstack_for_multiparameter_attributes(pairs)
      attributes = { }

      for pair in pairs
        multiparameter_name, value = pair
        attribute_name = multiparameter_name.split("(").first
        attributes[attribute_name] = [] unless attributes.include?(attribute_name)

        position = find_parameter_position(multiparameter_name)
        value = value.empty? ? nil : type_cast_attribute_value(multiparameter_name, value)
        attributes[attribute_name] << [position, value]
      end
      attributes.each { |name, values| attributes[name] = values.sort_by{ |v| v.first }.collect { |v| v.last } }
    end

    def type_cast_attribute_value(multiparameter_name, value)
      multiparameter_name =~ /\([0-9]*([a-z])\)/ ? value.send("to_" + $1) : value
    end

    def find_parameter_position(multiparameter_name)
      multiparameter_name.scan(/\(([0-9]*).*\)/).first.first
    end

    # Quote strings appropriately for SQL statements.
    def quote_value(value, column = nil)
      self.class.connection.quote(value, column)
    end

    def create_or_update
      raise NotImplemented
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id. Generate a UUID as the row key.
    def create
      raise NotImplemented
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    def update
      raise NotImplemented
    end

    # Update this record in hbase. Cannot be directly in the method 'update' because it would trigger callbacks and
    # therefore weird behaviors.
    def update_bigrecord
      timestamp = self.respond_to?(:updated_at) ? self.updated_at.to_bigrecord_timestamp : Time.now.to_bigrecord_timestamp
      connection.update(self.class.table_name, id, clone_in_persistence_format, timestamp)
    end

    # Allows access to the object attributes, which are held in the @attributes hash, as were
    # they first-class methods. So a Person class with a name attribute can use Person#name and
    # Person#name= and never directly use the attributes hash -- except for multiple assigns with
    # ActiveRecord#attributes=. A Milestone class can also ask Milestone#completed? to test that
    # the completed attribute is not nil or 0.
    #
    # It's also possible to instantiate related objects, so a Client class belonging to the clients
    # table with a master_id foreign key can instantiate master through Client#master.
    def method_missing(method_id, *args, &block)
      method_name = method_id.to_s
      if column_for_attribute(method_name) or
          ((md = /\?$/.match(method_name)) and
          column_for_attribute(query_method_name = md.pre_match) and
          method_name = query_method_name)
        define_read_methods if self.class.read_methods.empty? && self.class.generate_read_methods
        md ? query_attribute(method_name) : read_attribute(method_name)
      elsif self.class.primary_key.to_s == method_name
        id
      elsif (md = self.class.match_attribute_method?(method_name))
        attribute_name, method_type = md.pre_match, md.to_s
        if column_for_attribute(attribute_name)
          __send__("attribute#{method_type}", attribute_name, *args, &block)
        else
          super
        end
      else
        super
      end
    end

    # Removes any attributes from the argument hash that have been declared as protected
    # from mass assignment. See the {#attr_protected} and {#attr_accessible} macros to define
    # these attributes.
    def remove_attributes_protected_from_mass_assignment(attributes)
      safe_attributes =
        if self.class.accessible_attributes.nil? && self.class.protected_attributes.nil?
          attributes.reject { |key, value| attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        elsif self.class.protected_attributes.nil?
          attributes.reject { |key, value| !self.class.accessible_attributes.include?(key.gsub(/\(.+/, "")) || attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        elsif self.class.accessible_attributes.nil?
          attributes.reject { |key, value| self.class.protected_attributes.include?(key.gsub(/\(.+/,"")) || attributes_protected_by_default.include?(key.gsub(/\(.+/, "")) }
        else
          raise "Declare either attr_protected or attr_accessible for #{self.class}, but not both."
        end

      if !self.new_record? && !self.class.create_accessible_attributes.nil?
        safe_attributes = safe_attributes.delete_if{ |key, value| self.class.create_accessible_attributes.include?(key.gsub(/\(.+/,"")) }
      end

      removed_attributes = attributes.keys - safe_attributes.keys

      if removed_attributes.any?
        log_protected_attribute_removal(removed_attributes)
      end

      safe_attributes
    end

    # Removes attributes which have been marked as readonly.
    def remove_readonly_attributes(attributes)
      unless self.class.readonly_attributes.nil?
        attributes.delete_if { |key, value| self.class.readonly_attributes.include?(key.gsub(/\(.+/,"")) }
      else
        attributes
      end
    end

    def log_protected_attribute_removal(*attributes)
      logger.debug "WARNING: Can't mass-assign these protected attributes: #{attributes.join(', ')}"
    end

    # The primary key and inheritance column can never be set by mass-assignment for security reasons.
    def attributes_protected_by_default
      # default = [ self.class.primary_key, self.class.inheritance_column ]
      # default << 'id' unless self.class.primary_key.eql? 'id'
      # default
      []
    end

  protected

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    def read_attribute(attr_name)
      attr_name = attr_name.to_s
      if !(value = @attributes[attr_name]).nil?
        if column = column_for_attribute(attr_name)
          write_attribute(attr_name, column.type_cast(value))
        else
          value
        end
      else
        nil
      end
    end

    def read_attribute_before_type_cast(attr_name)
      @attributes[attr_name.to_s]
    end

  private

    # Called on first read access to any given column and generates reader
    # methods for all columns in the columns_hash if
    # BigRecord::Base.generate_read_methods is set to true.
    def define_read_methods
      self.class.columns_hash.each do |name, column|
        unless respond_to_without_attributes?(name)
          define_read_method(name.to_sym, name, column)
        end

        unless respond_to_without_attributes?("#{name}?")
          define_question_method(name)
        end
      end
    end

    # Define an attribute reader method. Cope with a nil column.
    def define_read_method(symbol, attr_name, column)
      cast_code = column.type_cast_code('v') if column
      access_code = cast_code ? "(v=@attributes['#{attr_name}']) && #{cast_code}" : "@attributes['#{attr_name}']"

      unless attr_name.to_s == self.class.primary_key.to_s
        access_code = access_code.insert(0, "raise NoMethodError, 'missing attribute: #{attr_name}', caller unless @attributes.has_key?('#{attr_name}'); ")
        self.class.read_methods << attr_name
      end

      evaluate_read_method attr_name, "def #{symbol}; #{access_code}; end"
    end

    # Define an attribute ? method.
    def define_question_method(attr_name)
      unless attr_name.to_s == self.class.primary_key.to_s
        self.class.read_methods << "#{attr_name}?"
      end

      evaluate_read_method attr_name, "def #{attr_name}?; query_attribute('#{attr_name}'); end"
    end

    # Evaluate the definition for an attribute reader or ? method
    def evaluate_read_method(attr_name, method_definition)
      begin
        self.class.class_eval(method_definition)
      rescue SyntaxError => err
        self.class.read_methods.delete(attr_name)
        if logger
          logger.warn "Exception occurred during reader method compilation."
          logger.warn "Maybe #{attr_name} is not a valid Ruby identifier?"
          logger.warn "#{err.message}"
        end
      end
    end

    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings for fixnum and float
    # columns are turned into nil.
    def write_attribute(attr_name, value)
      attr_name = attr_name.to_s
      column = column_for_attribute(attr_name)

      raise "Invalid column for this bigrecord object (e.g., you tried to set a predicate value for an entity that is out of the predicate scope)" if column == nil

      if column.number?
        @attributes[attr_name] = convert_number_column_value(value)
      else
        @attributes[attr_name] = value
      end
    end

    def convert_number_column_value(value)
      case value
        when FalseClass then 0
        when TrueClass then 1
        when '' then nil
        else value
      end
    end

  public

    class << self

      # Evaluate the name of the column of the primary key only once
      def primary_key
        raise NotImplemented
      end

      # Log and benchmark multiple statements in a single block.
      #
      # @example
      #   Project.benchmark("Creating project") do
      #     project = Project.create("name" => "stuff")
      #     project.create_manager("name" => "David")
      #     project.milestones << Milestone.find(:all)
      #   end
      #
      # The benchmark is only recorded if the current level of the logger matches the <tt>log_level</tt>, which makes it
      # easy to include benchmarking statements in production software that will remain inexpensive because the benchmark
      # will only be conducted if the log level is low enough.
      #
      # The logging of the multiple statements is turned off unless <tt>use_silence</tt> is set to false.
      def benchmark(title, log_level = Logger::DEBUG, use_silence = true)
        if logger && logger.level == log_level
          result = nil
          seconds = Benchmark.realtime { result = use_silence ? silence { yield } : yield }
          logger.add(log_level, "#{title} (#{'%.5f' % seconds})")
          result
        else
          yield
        end
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, Logger::ERROR if logger
        yield
      ensure
        logger.level = old_logger_level if logger
      end

      # Overwrite the default class equality method to provide support for association proxies.
      def ===(object)
        object.is_a?(self)
      end

      def base_class
        raise NotImplemented
      end

      # Override this method in the subclasses to add new columns. This is different from ActiveRecord because
      # the number of columns in an Hbase table is variable.
      def columns
        @columns = columns_hash.values
      end

      # Returns a hash of column objects for the table associated with this class.
      def columns_hash
        unless @all_columns_hash
          # add default hbase columns
          @all_columns_hash =
            if self == base_class
              if @columns_hash
                default_columns.merge(@columns_hash)
              else
                @columns_hash = default_columns
              end
            else
              if @columns_hash
                superclass.columns_hash.merge(@columns_hash)
              else
                superclass.columns_hash
              end
            end
        end
        @all_columns_hash
      end

      # Returns an array of column names as strings.
      def column_names
        @column_names = columns_hash.keys
      end

      # Returns an array of column objects where the primary id, all columns ending in "_id" or "_count",
      # and columns used for single table inheritance have been removed.
      def content_columns
        @content_columns ||= columns.reject{|c| c.primary || "id"}
      end

      # Returns a hash of all the methods added to query each of the columns in the table with the name of the method as the key
      # and true as the value. This makes it possible to do O(1) lookups in respond_to? to check if a given method for attribute
      # is available.
      def column_methods_hash #:nodoc:
        @dynamic_methods_hash ||= column_names.inject(Hash.new(false)) do |methods, attr|
          attr_name = attr.to_s
          methods[attr.to_sym]       = attr_name
          methods["#{attr}=".to_sym] = attr_name
          methods["#{attr}?".to_sym] = attr_name
          methods["#{attr}_before_type_cast".to_sym] = attr_name
          methods
        end
      end

      # Macro for defining a new column for a model. Invokes {create_column} and
      # adds the new column into the model's column hash.
      #
      # @param type [Symbol, String] Column type as defined in the source of {ConnectionAdapters::Column#klass}
      # @param [Hash] options The options to define the column with.
      # @option options [TrueClass,FalseClass] :collection Whether this column is a collection.
      # @option options [String] :alias Define an alias for the column that cannot be inferred. By default, 'attribute:name' will be aliased to 'name'.
      # @option options [String] :default Default value to set for this column.
      #
      # @return [ConnectionAdapters::Column] The column object created.
      def column(name, type, options={})
        name = name.to_s

        @columns_hash = default_columns unless @columns_hash

        # The other variables that are cached and depend on @columns_hash need to be reloaded
        invalidate_columns

        c = create_column(name, type, options)
        @columns_hash[c.name] = c

        alias_attribute c.alias, c.name if c.alias

        c
      end

      # Define aliases to the fully qualified attributes
      def alias_attribute(alias_name, fully_qualified_name)
        self.class_eval <<-EOF
          def #{alias_name}
            read_attribute("#{fully_qualified_name}")
          end
          def #{alias_name}=(value)
            write_attribute("#{fully_qualified_name}", value)
          end
        EOF
      end

      # Contains the names of the generated reader methods.
      def read_methods
        @read_methods ||= Set.new
      end

      # Transforms attribute key names into a more humane format, such as "First name" instead of "first_name". Example:
      #   Person.human_attribute_name("first_name") # => "First name"
      # Deprecated in favor of just calling "first_name".humanize
      def human_attribute_name(attribute_key_name) #:nodoc:
        attribute_key_name.humanize
      end

      def quote_value(value, c = nil) #:nodoc:
        connection.quote(value,c)
      end

      # Finder methods must instantiate through this method.
      def instantiate(raw_record)
        record = self.allocate
        record.deserialize(raw_record)
        record.preinitialize(raw_record)
        record.instance_variable_set(:@new_record, false)
        record.send("safe_attributes=", raw_record, false)
        record
      end

      # Attributes named in this macro are protected from mass-assignment,
      # such as <tt>new(attributes)</tt>,
      # <tt>update_attributes(attributes)</tt>, or
      # <tt>attributes=(attributes)</tt>.
      #
      # Mass-assignment to these attributes will simply be ignored, to assign
      # to them you can use direct writer methods. This is meant to protect
      # sensitive attributes from being overwritten by malicious users
      # tampering with URLs or forms.
      #
      #   class Customer < ActiveRecord::Base
      #     attr_protected :credit_rating
      #   end
      #
      #   customer = Customer.new("name" => David, "credit_rating" => "Excellent")
      #   customer.credit_rating # => nil
      #   customer.attributes = { "description" => "Jolly fellow", "credit_rating" => "Superb" }
      #   customer.credit_rating # => nil
      #
      #   customer.credit_rating = "Average"
      #   customer.credit_rating # => "Average"
      #
      # To start from an all-closed default and enable attributes as needed,
      # have a look at +attr_accessible+.
      def attr_protected(*attributes)
        write_inheritable_attribute(:attr_protected, Set.new(attributes.map {|a| a.to_s}) + (protected_attributes || []))
      end

      # Returns an array of all the attributes that have been protected from mass-assignment.
      def protected_attributes # :nodoc:
        read_inheritable_attribute(:attr_protected)
      end

      # Specifies a white list of model attributes that can be set via
      # mass-assignment, such as <tt>new(attributes)</tt>,
      # <tt>update_attributes(attributes)</tt>, or
      # <tt>attributes=(attributes)</tt>
      #
      # This is the opposite of the +attr_protected+ macro: Mass-assignment
      # will only set attributes in this list, to assign to the rest of
      # attributes you can use direct writer methods. This is meant to protect
      # sensitive attributes from being overwritten by malicious users
      # tampering with URLs or forms. If you'd rather start from an all-open
      # default and restrict attributes as needed, have a look at
      # +attr_protected+.
      #
      #   class Customer < ActiveRecord::Base
      #     attr_accessible :name, :nickname
      #   end
      #
      #   customer = Customer.new(:name => "David", :nickname => "Dave", :credit_rating => "Excellent")
      #   customer.credit_rating # => nil
      #   customer.attributes = { :name => "Jolly fellow", :credit_rating => "Superb" }
      #   customer.credit_rating # => nil
      #
      #   customer.credit_rating = "Average"
      #   customer.credit_rating # => "Average"
      def attr_accessible(*attributes)
        write_inheritable_attribute(:attr_accessible, Set.new(attributes.map(&:to_s)) + (accessible_attributes || []))
      end

      # Returns an array of all the attributes that have been made accessible to mass-assignment.
      def accessible_attributes # :nodoc:
        read_inheritable_attribute(:attr_accessible)
      end

      # Attributes listed as readonly can be set for a new record, but will be ignored in database updates afterwards.
      def attr_readonly(*attributes)
       write_inheritable_attribute(:attr_readonly, Set.new(attributes.map(&:to_s)) + (readonly_attributes || []))
      end

      # Returns an array of all the attributes that have been specified as readonly.
      def readonly_attributes
       read_inheritable_attribute(:attr_readonly)
      end

      # Attributes listed as create_accessible work with mass assignment ONLY on creation. After that, any updates
      # to that attribute will be protected from mass assignment. This differs from attr_readonly since that macro
      # prevents attributes from ever being changed (even with the explicit setters) after the record is created.
      #
      #   class Customer < BigRecord::Base
      #     attr_create_accessible :name
      #   end
      #
      #   customer = Customer.new(:name => "Greg")
      #   customer.name # => "Greg"
      #   customer.save # => true
      #
      #   customer.attributes = { :name => "Nerd" }
      #   customer.name # => "Greg"
      #   customer.name = "Nerd"
      #   customer.name # => "Nerd"
      #
      def attr_create_accessible(*attributes)
       write_inheritable_attribute(:attr_create_accessible, Set.new(attributes.map(&:to_s)) + (create_accessible_attributes || []))
      end

      # Returns an array of all the attributes that have been specified as create_accessible.
      def create_accessible_attributes
       read_inheritable_attribute(:attr_create_accessible)
      end

      # Guesses the table name, but does not decorate it with prefix and suffix information.
      def undecorated_table_name(class_name = base_class.name)
        table_name = Inflector.underscore(Inflector.demodulize(class_name))
        table_name = Inflector.pluralize(table_name) if pluralize_table_names
        table_name
      end

    protected

      def invalidate_views
        @views = nil
        @view_names = nil
      end

      def invalidate_columns
        @columns = nil
        @column_names = nil
        @content_columns = nil
      end

      # Creates a {ConnectionAdapters::Column} object.
      def create_column(name, type, options)
        ConnectionAdapters::Column.new(name, type, options)
      end

      def default_columns
        raise NotImplemented
      end

      def default_views
        {:all=>ConnectionAdapters::View.new('all', nil, self), :default=>ConnectionAdapters::View.new('default', nil, self)}
      end

      def subclasses #:nodoc:
        @@subclasses[self] ||= []
        @@subclasses[self] + @@subclasses[self].inject([]) {|list, subclass| list + subclass.subclasses }
      end

      # Returns the class type of the record using the current module as a prefix. So descendents of
      # MyApp::Business::Account would appear as MyApp::Business::AccountSubclass.
      def compute_type(type_name)
        type_name.constantize
      end

    end

  protected

    # Handle *? for method_missing.
    def attribute?(attribute_name)
      query_attribute(attribute_name)
    end

    # Handle *= for method_missing.
    def attribute=(attribute_name, value)
      write_attribute(attribute_name, value)
    end

    # Handle *_before_type_cast for method_missing.
    def attribute_before_type_cast(attribute_name)
      read_attribute_before_type_cast(attribute_name)
    end
  end
end
