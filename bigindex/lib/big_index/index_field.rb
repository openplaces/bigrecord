module BigIndex

  class IndexField

    attr_reader :field, :field_name, :field_type, :options, :block

    def initialize(params, block = nil)
      raise "IndexField requires at least a field name" unless params.size > 0

      @params = params.dup
      @block = block

      @field_name = params.shift

      unless params.empty?
        @field_type = params.shift
      end

      @options = params.shift || {}

      # Setting the default values
      @options[:finder_name] ||= field_name
      @field_type ||= :text
    end

    def [](name)
      @options[name]
    end

    def method_missing(name)
      @options[name.to_sym] || super
    end

  end # class IndexField

end # module BigIndex
