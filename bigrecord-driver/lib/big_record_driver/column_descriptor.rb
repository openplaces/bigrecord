module BigRecordDriver

  class ColumnDescriptor

    attr_accessor :name
    attr_accessor :versions
    attr_accessor :max_value_length
    attr_accessor :in_memory
    attr_accessor :bloom_filter
    attr_accessor :compression

    def initialize(name, options={})
      raise ArgumentError, "name is mandatory" unless name

      @name = name.to_s
      @versions         = options[:versions]
      @max_value_length = options[:max_value_length]
      @in_memory        = options[:in_memory]
      @bloom_filter     = options[:bloom_filter]
      @compression      = options[:compression]
    end

  end

end
