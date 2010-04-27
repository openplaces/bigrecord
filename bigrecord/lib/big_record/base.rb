module BigRecord

  class Base < Model

    attr_accessor :modified_attributes

    def self.inherited(child) #:nodoc:
      @@subclasses[self] ||= []
      @@subclasses[self] << child
      child.set_table_name child.name.tableize if child.superclass == BigRecord::Base
      super
    end

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    def initialize(attrs = nil)
      @new_record = true
      super
      attrs.keys.each{ |k| set_loaded(k) } if attrs
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    # (Alias for the protected read_attribute method).
    def [](attr_name)
      if attr_name.ends_with?(":")
        read_family_attributes(attr_name)
      else
        read_attribute(attr_name)
      end
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    def read_attribute(attr_name, options={})
      attr_name = attr_name.to_s
      column = column_for_attribute(attr_name)
      if column
        # First check if the attribute is already in the attributes hash
        if @attributes.has_key?(attr_name) and options.blank?
          super(attr_name)
        # Elsif the column exist, we try to lazy load it
        elsif !(is_loaded?(attr_name)) and attr_name != self.class.primary_key and !new_record?
          unless self.all_attributes_loaded? and attr_name =~ /\A#{self.class.default_family}:/
            if options.blank?
              # Normal behavior

              # Retrieve the version of the attribute matching the current record version
              options[:timestamp] = self.updated_at.to_bigrecord_timestamp if self.has_attribute?("#{self.class.default_family}:updated_at") and self.updated_at

              # get the content of the cell
              value = connection.get(self.class.table_name, self.id, attr_name, options)

              set_loaded(attr_name)
              write_attribute(attr_name, column.type_cast(value))
            else
              # Special request... don't keep it in the attributes hash
              options[:timestamp] ||= self.updated_at.to_bigrecord_timestamp if self.has_attribute?("#{self.class.default_family}:updated_at") and self.updated_at

              # get the content of the cell
              value = connection.get(self.class.table_name, self.id, attr_name, options)

              if options[:versions] and options[:versions] > 1
                value.collect{ |v| column.type_cast(v) }
              else
                column.type_cast(value)
              end
            end
          else
            write_attribute(attr_name, column.default)
          end
        else
          write_attribute(attr_name, column.default)
        end
      else
        nil
      end
    end

    # Read an attribute that defines a column family.
    def read_family_attributes(attr_name)
      attr_name = attr_name.to_s
      column = column_for_attribute(attr_name)
      if column
        # First check if the attribute is already in the attributes hash
        if @attributes.has_key?(attr_name)
          if (values = @attributes[attr_name]) and values.is_a?(Hash)
            values.delete(self.class.primary_key)
            casted_values = {}
            values.each{|k,v| casted_values[k] = column.type_cast(v)}
            write_attribute(attr_name, casted_values)
          else
            write_attribute(attr_name, {})
          end

        # Elsif the column exist, we try to lazy load it
        elsif !(is_loaded?(attr_name)) and attr_name != self.class.primary_key and !new_record?
          unless self.all_attributes_loaded? and attr_name =~ /\A#{self.class.default_family}:/
            options = {}
            # Retrieve the version of the attribute matching the current record version
            options[:timestamp] = self.updated_at.to_bigrecord_timestamp if self.has_attribute?("#{self.class.default_family}:updated_at") and self.updated_at

            # get the content of the whole family
            values = connection.get_columns(self.class.table_name, self.id, [attr_name], options)
            if values
              values.delete(self.class.primary_key)
              casted_values = {}
              values.each do |k,v|
                short_name = k.split(":")[1]
                casted_values[short_name] = column.type_cast(v) if short_name
                set_loaded(k)
                write_attribute(k, casted_values[short_name]) if short_name
              end
              write_attribute(attr_name, casted_values)
            else
              set_loaded(attr_name)
              write_attribute(attr_name, {})
            end
          else
            write_attribute(attr_name, column.default)
          end
        else
          write_attribute(attr_name, column.default)
        end
      else
        nil
      end
    end

    def set_loaded(name)
      @loaded_columns ||= []
      @loaded_columns << name
    end

    def is_loaded?(name)
      @loaded_columns ||= []
      @loaded_columns.include?(name)
    end

  public
    # Returns true if this object hasn't been saved yet -- that is, a record for the object doesn't exist yet.
    def new_record?
      @new_record
    end

    # * No record exists: Creates a new record with values matching those of the object attributes.
    # * A record does exist: Updates the record with values matching those of the object attributes.
    def save
      create_or_update
    end

    # Attempts to save the record, but instead of just returning false if it couldn't happen, it raises a
    # RecordNotSaved exception
    def save!
      create_or_update || raise(RecordNotSaved)
    end

    # Deletes the record in the database and freezes this instance to reflect that no changes should
    # be made (since they can't be persisted).
    def destroy
      unless new_record?
        connection.delete(self.class.table_name, self.id)
      end

      # FIXME: this currently doesn't work because we write the attributes everytime we read them
      # which means that we cannot read the attributes of a deleted record... it's bad
#      freeze
    end

    # Updates a single attribute and saves the record. This is especially useful for boolean flags on existing records.
    # Note: This method is overwritten by the Validation module that'll make sure that updates made with this method
    # doesn't get subjected to validation checks. Hence, attributes can be updated even if the full object isn't valid.
    def update_attribute(name, value)
      send(name.to_s + '=', value)
      save
    end

    # Updates all the attributes from the passed-in Hash and saves the record. If the object is invalid, the saving will
    # fail and false will be returned.
    def update_attributes(attributes)
      self.attributes = attributes
      save
    end

    # Updates an object just like Base.update_attributes but calls save! instead of save so an exception is raised if the record is invalid.
    def update_attributes!(attributes)
      self.attributes = attributes
      save!
    end

    def connection
      self.class.connection
    end

  protected

    # Invoke {#create} if {#new_record} returns true, otherwise it's an {#update}
    def create_or_update
      raise ReadOnlyRecord if readonly?
      result = new_record? ? create : update
      result != false
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id. Generate a UUID as the row key.
    def create
      self.id = generate_new_id unless self.id
      @new_record = false
      update_bigrecord
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    def update
      update_bigrecord
    end

    # Update this record in hbase. Cannot be directly in the method 'update' because it would trigger callbacks and
    # therefore weird behaviors.
    def update_bigrecord
      timestamp = self.respond_to?(:updated_at) ? self.updated_at.to_bigrecord_timestamp : Time.now.to_bigrecord_timestamp

      data = clone_in_persistence_format

      connection.update(self.class.table_name, id, data, timestamp)
    end

  public
    class << self

      # Return the name of the primary key. Defaults to "id".
      def primary_key
        @primary_key ||= "id"
      end

      # Return the list of families for this class
      def families
        columns.collect(&:family).uniq
      end

      # HBase scanner utility -- scans the table and executes code on each record
      #
      # @example
      #    Entity.scan(:batch_size => 200) {|e|puts "#{e.name} is a child!" if e.parent}
      #
      # @option options [Integer] :batch_size - number of records to retrieve from database with each scan iteration.
      # @option options [Block] :code - the code to execute (see example above for syntax)
      #
      def scan(options={}, &code)
        options = options.dup
        limit = options.delete(:batch_size) || 100

        items_processed = 0

        # add an extra record for defining the next offset without duplicating records
        limit += 1
        last_row_id = nil

        while true
          items = find(:all, options.merge({:limit => limit}))

          # set the new offset as the extra record
          unless items.empty?
            items.delete_at(0) if items[0].id == last_row_id

            break if items.empty?

            last_row_id = items.last.id
            options[:offset] = last_row_id
            items_processed += items.size

            items.each do |item|
              code.call(item)
            end
          else
            break
          end
        end
      end

      def find(*args)
        options = extract_options_from_args!(args)
        validate_find_options(options)

        # set a default view
        if options[:view]
          options[:view] = options[:view].to_sym
        else
          options[:view] = :default
        end

        case args.first
          when :first then find_every(options.merge({:limit => 1})).first
          when :all   then find_every(options)
          else             find_from_ids(args, options)
        end
      end

      # Returns true if the given +id+ represents the primary key of a record in the database, false otherwise.
      def exists?(id)
        !find(id).nil?
      rescue BigRecord::BigRecordError
        false
      end

      # Creates an object, instantly saves it as a record (if the validation permits it), and returns it. If the save
      # fails under validations, the unsaved object is still returned.
      def create(attrs = nil)
        if attrs.is_a?(Array)
          attrs.collect { |attr| create(attr) }
        else
          object = new(attrs)
          object.save
          object
        end
      end

      # Finds the record from the passed +id+, instantly saves it with the passed +attributes+ (if the validation permits it),
      # and returns it. If the save fails under validations, the unsaved object is still returned.
      #
      # The arguments may also be given as arrays in which case the update method is called for each pair of +id+ and
      # +attributes+ and an array of objects is returned.
      #
      # @example of updating one record:
      #   Person.update(15, {:user_name => 'Samuel', :group => 'expert'})
      #
      # @example of updating multiple records:
      #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy"} }
      #   Person.update(people.keys, people.values)
      def update(id, attributes)
        if id.is_a?(Array)
          idx = -1
          id.collect { |a| idx += 1; update(a, attributes[idx]) }
        else
          object = find(id)
          object.update_attributes(attributes)
          object
        end
      end

      # Deletes the record with the given +id+ without instantiating an object first. If an array of ids is provided, all of them
      # are deleted.
      def delete(id)
        if id.is_a?(Array)
          id.each { |a| connection.delete(table_name, a) }
        else
          connection.delete(table_name, id)
        end
      end

      # Destroys the record with the given +id+ by instantiating the object and calling #destroy (all the callbacks are the triggered).
      # If an array of ids is provided, all of them are destroyed.
      def destroy(id)
        id.is_a?(Array) ? id.each { |a| destroy(a) } : find(id).destroy
      end

      # Updates all records with the SET-part of an SQL update statement in +updates+ and returns an integer with the number of rows updated.
      # A subset of the records can be selected by specifying +conditions+. Example:
      #   Billing.update_all "category = 'authorized', approved = 1", "author = 'David'"
      def update_all(updates, conditions = nil)
        raise NotImplemented, "update_all"
      end

      # Destroys the objects for all the records that match the +condition+ by instantiating each object and calling
      # the destroy method. Example:
      #   Person.destroy_all "last_login < '2004-04-04'"
      def destroy_all(conditions = nil)
        find(:all, :conditions => conditions).each { |object| object.destroy }
      end

      # Deletes all the records that match the +condition+ without instantiating the objects first (and hence not
      # calling the destroy method). Example:
      #   Post.delete_all "person_id = 5 AND (category = 'Something' OR category = 'Else')"
      #
      # @todo take into consideration the conditions
      def delete_all(conditions = nil)
        connection.get_consecutive_rows(table_name, nil, nil, ["#{default_family}:"]).each do |row|
          connection.delete(table_name, row["id"])
        end
      end

      # Truncate the table for this model
      def truncate
        connection.truncate_table(table_name)
      end

      def table_name
        @table_name || superclass.table_name
      end

      def set_table_name(name)
        @table_name = name.to_s
      end

      # Get the default column family used to store attributes that have no column family set explicitly.
      #
      # Defaults to "attribute"
      def default_family
        @default_family ||= "attribute"
      end

      # Set the default column family used to store attributes that have no column family set explicitly.
      #
      # @example
      #   set_default_family :attr  # instead of using :attribute as the default.
      def set_default_family(name)
        @default_family = name.to_s
      end

      # @return [Class] The base class which inherits BigRecord::Base directly.
      def base_class
        (superclass == BigRecord::Base) ? self : superclass.base_class
      end

      # Macro for defining a named view to a list of columns.
      #
      # @param [String, Symbol] name Give it an arbitrary name.
      # @param [Array<String, Symbol>] columns List of columns to associate to this view. Can use column aliases or fully qualified names.
      #
      # @example
      #   view :front_page, :name, :title, :description
      #   view :summary, ["attribute:name", "attribute:title"]
      def view(name, *columns)
        name = name.to_sym
        @views_hash ||= default_views

        # The other variables that are cached and depend on @views_hash need to be reloaded
        invalidate_views

        @views_hash[name] = ConnectionAdapters::View.new(name, columns.flatten, self)
      end

      # Get a list of all the views defined by the {view} macro for the model.
      def views
        @views ||= views_hash.values
      end

      # Get a list of view names defined by {view}.
      def view_names
        @view_names ||= views_hash.keys
      end

      # Get the full hash of views consisting of the name as keys, and the {ConnectionAdapters::View} views.
      def views_hash
        unless @all_views_hash
          # add default hbase columns
          @all_views_hash =
            if self == BigRecord::Base # stop at Base
               @views_hash = default_views
            else
              if @views_hash
                superclass.views_hash.merge(default_views).merge(@views_hash)
              else
                superclass.views_hash.merge(default_views)
              end
            end
        end
        @all_views_hash
      end

      # Default columns to create with the model, such as primary key.
      def default_columns
        {primary_key => ConnectionAdapters::Column.new(primary_key, 'string')}
      end

      def default_column_prefix
        "#{default_family}:"
      end

      # Return the hash of default views which consist of all columns and the :default named views.
      def default_views
        {:all=>ConnectionAdapters::View.new('all', nil, self), :default=>ConnectionAdapters::View.new('default', nil, self)}
      end

      # Return the list of fully qualified column names, i.e. ["family:qualifier"].
      #
      # Returns the column names based on the options argument in order of
      # :columns,then :view, i.e. disregards :view if :columns is defined.
      #
      # @option options [Array<String, Symbol>] :columns List of fully qualified column names or column aliases.
      # @option options [String, Symbol] :view The name of the view as defined with {view}.
      def columns_to_find(options={})
        c =
          if options[:columns]
            column_list = []
            options[:columns].each do |column_name|
              # If the column name provided is a full name, i.e. includes column family and qualifier,
              # then add it to the list.
              if column_name.to_s =~ /:/
                column_list << column_name

              # Otherwise, it's probably an alias and we need to check that.
              else
                columns.select{|column| column_list << column.name if column.alias == column_name.to_s}
              end
            end
            column_list
          elsif options[:view]
            raise ArgumentError, "Unknown view: #{options[:view]}" unless views_hash[options[:view]]
            if options[:view] == :all
              ["#{default_family}:"]
            else
              views_hash[options[:view]].column_names
            end
          elsif views_hash[:default]
            views_hash[:default].column_names
          else
            ["#{default_family}:"]
          end
        c += [options[:include]] if options[:include]
        c.flatten.reject{|x| x == "id"}
      end

    protected
      def invalidate_views
        @views = nil
        @view_names = nil
      end

      def extract_options_from_args!(args) #:nodoc:
        args.last.is_a?(Hash) ? args.pop : {}
      end

      VALID_FIND_OPTIONS = [:limit, :offset, :include, :view, :versions, :timestamp,
                            :include_deleted, :force_reload, :columns, :stop_row]

      def validate_find_options(options) #:nodoc:
        options.assert_valid_keys(VALID_FIND_OPTIONS)
      end

      def find_every(options)
        requested_columns = columns_to_find(options)

        raw_records = connection.get_consecutive_rows(table_name, options[:offset],
          options[:limit], requested_columns, options[:stop_row])

        raw_records.collect do |raw_record|
          add_missing_cells(raw_record, requested_columns)
          rec = instantiate(raw_record)
          rec.all_attributes_loaded = true if options[:view] == :all
          rec
        end
      end

      def find_from_ids(ids, options)
        expects_array = ids.first.kind_of?(Array)
        return ids.first if expects_array && ids.first.empty?

        ids = ids.flatten.compact.uniq

        case ids.size
          when 0
            raise RecordNotFound, "Couldn't find #{name} without an ID"
          when 1
            result = find_one(ids.first, options)
            expects_array ? [ result ] : result
          else
            ids.collect do |id|
              find_one(id, options)
            end
        end
      end

      def find_one(id, options)
        # allow to pass a record (e.g. Entity.find(@entity)) and not only a string (e.g. Entity.find("$-monkey-123"))
        unless id.is_a?(String)
          id = id.id if id and not id.is_a?(String)
        end

        # Allow the client to give us other objects than integers, e.g. Time and String
        if options[:timestamp] && options[:timestamp].kind_of?(Time)
          options[:timestamp] = options[:timestamp].to_bigrecord_timestamp
        end

        requested_columns = columns_to_find(options)

        # TODO: this is a hack... it should be done in a single call but currently hbase doesn't allow that
        raw_record =
        if options[:versions] and options[:versions] > 1
          timestamps = connection.get(table_name, id, "#{default_family}:updated_at", options)
          timestamps.collect{|timestamp| connection.get_columns(table_name, id, requested_columns, :timestamp => timestamp.to_bigrecord_timestamp)}
        else
          connection.get_columns(table_name, id, requested_columns, options)
        end

        # Instantiate the raw record (or records, if multiple versions were asked)
        if raw_record
          if raw_record.is_a?(Array)
            unless raw_record.empty?
              raw_record.collect do |r|
                add_missing_cells(r, requested_columns)
                rec = instantiate(r)
                rec.all_attributes_loaded = true if options[:view] == :all
                rec
              end
            else
              raise RecordNotFound, "Couldn't find #{name} with ID=#{id}"
            end
          else
            add_missing_cells(raw_record, requested_columns)
            rec = instantiate(raw_record)
            rec.all_attributes_loaded = true if options[:view] == :all
            rec
          end
        else
          raise RecordNotFound, "Couldn't find #{name} with ID=#{id}"
        end
      end

      def find_all_by_id(ids, options={})
        ids.inject([]) do |result, id|
          begin
            result << find_one(id, options)
          rescue BigRecord::RecordNotFound => e
          end
          result
        end
      end

      # Add the missing cells to the raw record and set them to nil. We know that it's
      # nil because else we would have received those cells. That way, when the value of
      # one of these cells will be requested by the client we won't try to lazy load it.
      def add_missing_cells(raw_record, requested_columns)
        requested_columns.each do |k, v|
          # don't do it for column families (e.g. attribute:)
          unless k =~ /:$/
            raw_record[k] = nil unless raw_record.has_key?(k)
          end
        end
      end

      # Define aliases to the fully qualified attributes
      def alias_attribute(alias_name, fully_qualified_name)
        self.class_eval <<-EOF
          def #{alias_name}(options={})
            read_attribute("#{fully_qualified_name}", options)
          end
          def #{alias_name}=(value)
            write_attribute("#{fully_qualified_name}", value)
          end
        EOF
      end

    end

  end
end
