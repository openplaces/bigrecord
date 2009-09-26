require File.join(File.dirname(__FILE__), 'support')

module BigIndex

  class IndexField
    include Assertions

    attr_reader :field, :field_name, :field_type, :options, :block

    def initialize(params, block = nil)
      raise "IndexField requires at least a field name" unless params.size > 0

      @params = params.dup
      @block = block

      @field_name = params.shift
      assert_kind_of 'field_name', @field_name, Symbol, String

      unless params.empty? || ![Symbol, String].include?(params.first.class)
        @field_type = params.shift
      end

      @options = params.shift || {}
      assert_kind_of 'options', @options, Hash

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
