module BigRecord
  module Driver

    class ColumnDescriptor
      attr_accessor :name, :versions, :in_memory, :bloom_filter, :compression

      def initialize(name, options={})
        raise ArgumentError, "name is mandatory" unless name

        @name = name.to_s
        @versions     = options[:versions]
        @in_memory    = options[:in_memory]
        @bloom_filter = options[:bloom_filter]
        @compression  = options[:compression]
      end
    end

  end
end

