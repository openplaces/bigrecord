require 'date'
require 'bigdecimal'
require 'bigdecimal/util'

module BigRecord
  module ConnectionAdapters #:nodoc:

    # = Column/Attribute Definition
    #
    # As long as a model has at least one column family set up for it, then
    # columns (a.k.a. model attributes) can then be defined for the model.
    #
    # The following is an example of a model named book.rb that has a
    # column family called "attribute" set up for it:
    #
    #   class Book < BigRecord::Base
    #     column 'attribute:title',   :string
    #     column :author,             :string
    #     column :description,        :string
    #     column :links,              :string,  :collection => true
    #   end
    #
    # This simple model defines 4 columns of type string. An important thing
    # to notice here is that the first column 'attribute:title' has the column
    # family prepended to it. This is identical to just passing the symbol
    # :title to the column method, and the default behaviour is to prepend
    # the column family (attribute) automatically if one is not defined.
    #
    # Furthermore, in HBase, there's the option of storing collections for a
    # given column. This will return an array for the links attribute on a
    # Book record.
    #
    # == Types and Options
    #
    # @see BigRecord::AbstractBase.column
    #
    class Column
      module Format
        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
      end

      attr_reader :name, :type, :collection, :default, :alias
      attr_accessor :primary

      COLLECTION_SEPARATOR = "::"

      def initialize(name, type, options={})
        @type       = type.to_sym
        @collection = options[:collection]
        @name       = name.to_s
        @alias      = options[:alias] ? options[:alias].to_s : (self.class.extract_qualifier(@name) || (@name unless family?))

        if options[:default]
          @default = options[:default]
        elsif @collection
          @default = []
        else
          @default = (@type == :boolean) ? false : nil
        end
        # cache whether or not we'll need to dup the default columns to avoid clients to share
        # the same reference to the default value
        @must_dup_default = (!@default.nil? and (collection or (!number? and @type != :boolean)))

        @primary          = nil
      end

      # callback may be implemented by subclasses if value needs to be 'massaged' before instantiation.
      def preinitialize(value)
        # do something to a column value's attributes before it is instantiated.
      end

      def default
        @must_dup_default ? @default.dup : @default
      end

      def text?
        [:string, :text].include? type
      end

      def number?
        [:float, :integer, :decimal].include? type
      end

      def primitive?
        @primitive ||= ([:integer, :float, :decimal, :datetime, :date, :timestamp, :time, :text, :string, :binary, :boolean, :map, :object].include? type)
      end

      def family?
        name =~ /:\Z/
      end

      def family
        self.class.extract_family(self.name)
      end

      def qualifier
        self.class.extract_qualifier(self.name)
      end

      def collection?
        @collection
      end

      # Returns the Ruby class that corresponds to the abstract data type.
      def klass
        @klass ||=
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :decimal       then BigDecimal
          when :datetime      then Time
          when :date          then Date
          when :timestamp     then Time
          when :time          then Time
          when :text, :string then String
          when :binary        then String
          when :boolean       then Object
          when :map           then Hash
          when :object        then Object
          else type.to_s.constantize
        end
      end

      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value)
        # FIXME: this should be recursive but it doesn't work with type_cast_code()... why does
        # ActiveRecord use type_cast_code ???
        if collection?
          return [] if value.nil?
          case type
            when :string    then self.class.hash_to_string_collection(value)
            when :text      then self.class.hash_to_string_collection(value)
            when :integer   then self.class.hash_to_integer_collection(value)
            when :float     then self.class.hash_to_float_collection(value)
            when :decimal   then self.class.hash_to_decimal_collection(value)
            when :datetime  then self.class.hash_to_time_collection(value)
            when :timestamp then self.class.hash_to_time_collection(value)
            when :time      then self.class.hash_to_dummy_time_collection(value)
            when :date      then self.class.hash_to_date_collection(value)
            when :binary    then self.class.hash_to_string_collection(value)
            when :boolean   then self.class.hash_to_boolean_collection(value)
            when :map       then value
            when :object    then value
            else hash_to_embedded_collection(value)
          end
        else
          casted_value =
          case type
            when :string    then value
            when :text      then value
            when :integer   then value.to_i rescue value ? 1 : 0
            when :float     then value.to_f rescue value ? 1.0 : 0.0
            when :decimal   then self.class.value_to_decimal(value)
            when :datetime  then self.class.string_to_time(value)
            when :timestamp then self.class.string_to_time(value)
            when :time      then self.class.string_to_dummy_time(value)
            when :date      then self.class.string_to_date(value)
            when :binary    then self.class.binary_to_string(value)
            when :boolean   then self.class.value_to_boolean(value)
            when :map       then value
            when :object    then value
            else hash_to_embedded(value)
          end
          # Make sure that the returned value matches the current schema.
          casted_value.is_a?(klass) ? casted_value : nil
        end
      end

      def type_cast_code(var_name)
        if collection?
          case type
            when :string    then "#{self.class.name}.hash_to_string_collection(#{var_name})"
            when :text      then "#{self.class.name}.hash_to_string_collection(#{var_name})"
            when :integer   then "#{self.class.name}.hash_to_integer_collection(#{var_name})"
            when :float     then "#{self.class.name}.hash_to_float_collection(#{var_name})"
            when :decimal   then "#{self.class.name}.hash_to_decimal_collection(#{var_name})"
            when :datetime  then "#{self.class.name}.hash_to_time_collection(#{var_name})"
            when :timestamp then "#{self.class.name}.hash_to_time_collection(#{var_name})"
            when :time      then "#{self.class.name}.hash_to_dummy_time_collection(#{var_name})"
            when :date      then "#{self.class.name}.hash_to_date_collection(#{var_name})"
            when :binary    then "#{self.class.name}.hash_to_string_collection(#{var_name})"
            when :boolean   then "#{self.class.name}.hash_to_boolean_collection(#{var_name})"
            when :map       then nil
            when :object    then nil
            else nil
          end
        else
          case type
            when :string    then nil
            when :text      then nil
            when :integer   then "(#{var_name}.to_i rescue #{var_name} ? 1 : 0)"
            when :float     then "#{var_name}.to_f"
            when :decimal   then "#{self.class.name}.value_to_decimal(#{var_name})"
            when :datetime  then "#{self.class.name}.string_to_time(#{var_name})"
            when :timestamp then "#{self.class.name}.string_to_time(#{var_name})"
            when :time      then "#{self.class.name}.value_to_dummy_time(#{var_name})"
            when :date      then "#{self.class.name}.string_to_date(#{var_name})"
            when :binary    then "#{self.class.name}.binary_to_string(#{var_name})"
            when :boolean   then "#{self.class.name}.value_to_boolean(#{var_name})"
            when :map       then nil
            when :object    then nil
            else nil
          end
        end
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name #=> 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
      end

      def hash_to_embedded_collection(hash)
        hash_collection = hash.is_a?(Hash) ? self.class.hash_to_collection(hash) : hash
        hash_collection_to_embedded_collection(hash_collection)
      end

      def hash_collection_to_embedded_collection(hash_collection)
        return hash_collection unless hash_collection.is_a?(Array)
        hash_collection.each_with_index do |hash, i|
          hash_collection[i] = hash_to_embedded(hash) if hash.is_a?(Hash)
        end
        hash_collection
      end

      def hash_to_embedded(value)
        case value
          when BigRecord::Embedded then value
          when Hash then self.klass.instantiate(value)
        end
      end

      class << self

        # Extract the family from a column name
        def extract_family(column_name)
          return nil unless column_name
          column_name =~ /\A(.*?:).*\Z/
          $1
        end

        # Extract the qualifier from a column name
        def extract_qualifier(column_name)
          return nil unless column_name
          column_name =~ /\A.*?:(.*)\Z/
          $1
        end

        # Extract the collection from the hash, where the positions are the keys. Inspired
        # from ActiveRecord::NestedAttributes.
        #
        #   params = { 'member' => {
        #     'name' => 'joe', 'posts_attributes' => {
        #       '1' => { 'title' => 'Kari, the awesome Ruby documentation browser!' },
        #       '2' => { 'title' => 'The egalitarian assumption of the modern citizen' },
        #       'new_67890' => { 'title' => '' } # This one matches the :reject_if proc and will not be instantiated.
        #     }
        #   }}
        def hash_to_collection(hash)
          return hash unless hash.is_a?(Hash)

          # Make sure any new records sorted by their id before they're build.
          sorted_by_id = hash.sort_by { |id, _| id.is_a?(String) ? id.sub(/^new_/, '').to_i : id }

          array = []
          sorted_by_id.each do |id, record_attributes|
            # remove blank records
            next if blank_or_invalid_record?(record_attributes)

            array << record_attributes
          end
          array
        end

        # Check if the given record is empty. It's recursive since it
        # can be an Embedded
        def blank_or_invalid_record?(record_attributes)
          return true if record_attributes.blank? or !record_attributes.is_a?(Hash)
          record_attributes.all? do |k, v|
            v.is_a?(Hash) ? (v.empty? or blank_or_invalid_record?(v)) : v.blank?
          end
        end

        def extract_callstack_for_multiparameter_attributes(pairs)
          attributes = { }

          for pair in pairs
            multiparameter_name, value = pair
            attribute_name = multiparameter_name.split("(").first
            attributes[attribute_name] = [] unless attributes.include?(attribute_name)

            unless value.empty?
              attributes[attribute_name] <<
                [ find_parameter_position(multiparameter_name), type_cast_attribute_value(multiparameter_name, value) ]
            end
          end

          attributes.each { |name, values| attributes[name] = values.sort_by{ |v| v.first }.collect { |v| v.last } }
        end

        def parse_collection(value)
          case value
            when String then value.split(COLLECTION_SEPARATOR)
            when Hash then value.values.first.scan(/\[(.*?)\]/).flatten
            when NilClass then []
            else value
          end
        end

        # strings are a special case...
        def hash_to_string_collection(value)
          parse_collection(value).collect(&:to_s)
        end

        def hash_to_integer_collection(value)
          parse_collection(value).collect(&:to_i)
        end

        def hash_to_float_collection(value)
          parse_collection(value).collect(&:to_f)
        end

        def hash_to_decimal_collection(value)
          parse_collection(value).collect{|v| value_to_decimal(v)}
        end

        def hash_to_date_collection(value)
          parse_collection(value).collect{|v| string_to_date(v.to_s)}
        end

        def hash_to_time_collection(value)
          parse_collection(value).collect{|v| string_to_time(v.to_s)}
        end

        def hash_to_dummy_time_collection(value)
          parse_collection(value).collect{|v| string_to_dummy_time(v.to_s)}
        end

        def hash_to_boolean_collection(value)
          parse_collection(value).collect{|v| value_to_boolean(v)}
        end

        # Used to convert from Strings to BLOBs
        def string_to_binary(value)
          value
        end

        # Used to convert from BLOBs to Strings
        def binary_to_string(value)
          value
        end

        def string_to_date(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_date(string) || fallback_string_to_date(string)
        end

        def string_to_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_time(string) || fallback_string_to_time(string)
        end

        def string_to_dummy_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          string_to_time "2000-01-01 #{string}"
        end

        # convert something to a boolean
        def value_to_boolean(value)
          if value == true || value == false
            value
          else
            %w(true t 1).include?(value.to_s.downcase)
          end
        end

        # convert something to a BigDecimal
        def value_to_decimal(value)
          if value.is_a?(BigDecimal)
            value
          elsif value.respond_to?(:to_d)
            value.to_d
          else
            value.to_s.to_d
          end
        end

        protected
          # '0.123456' -> 123456
          # '1.123456' -> 123456
          def microseconds(time)
            ((time[:sec_fraction].to_f % 1) * 1_000_000).to_i
          end

          def new_date(year, mon, mday)
            if year && year != 0
              Date.new(year, mon, mday) rescue nil
            end
          end

          def new_time(year, mon, mday, hour, min, sec, microsec)
            # Treat 0000-00-00 00:00:00 as nil.
            return nil if year.nil? || year == 0

            Time.send(Base.default_timezone, year, mon, mday, hour, min, sec, microsec)
          # Over/underflow to DateTime
          rescue ArgumentError, TypeError
            zone_offset = Base.default_timezone == :local ? DateTime.local_offset : 0
            DateTime.civil(year, mon, mday, hour, min, sec, zone_offset) rescue nil
          end

          def fast_string_to_date(string)
            if string =~ Format::ISO_DATE
              new_date $1.to_i, $2.to_i, $3.to_i
            end
          end

          # Doesn't handle time zones.
          def fast_string_to_time(string)
            if string =~ Format::ISO_DATETIME
              microsec = ($7.to_f * 1_000_000).to_i
              new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
            end
          end

          def fallback_string_to_date(string)
            new_date *ParseDate.parsedate(string)[0..2]
          end

          def fallback_string_to_time(string)
            time_hash = Date._parse(string)
            time_hash[:sec_fraction] = microseconds(time_hash)

            new_time *time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction)
          end
      end

      private
        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def extract_precision(sql_type)
          $2.to_i if sql_type =~ /^(numeric|decimal|number)\((\d+)(,\d+)?\)/i
        end

        def extract_scale(sql_type)
          case sql_type
            when /^(numeric|decimal|number)\((\d+)\)/i then 0
            when /^(numeric|decimal|number)\((\d+)(,(\d+))\)/i then $4.to_i
          end
        end

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double/i
              :float
            when /decimal|numeric|number/i
              extract_scale(field_type) == 0 ? :integer : :decimal
            when /datetime/i
              :datetime
            when /timestamp/i
              :timestamp
            when /time/i
              :time
            when /date/i
              :date
            when /clob/i, /text/i
              :text
            when /blob/i, /binary/i
              :binary
            when /char/i, /string/i
              :string
            when /boolean/i
              :boolean
          end
        end
    end
  end
end
