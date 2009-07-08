module BigIndex
  class Repository
    include Assertions

    @adapters = {}
    @default_name = :default

    ##
    #
    # @return <Adapter> the adapters registered for this repository
    def self.adapters
      @adapters
    end

    def self.context
      Thread.current[:bigindex_repository_contexts] ||= []
    end

    def self.default_name
      @default_name ||= :default
    end

    def self.default_name=(name)
      @default_name = name
    end

    # TODO: Make sure this isn't dangerous
    def self.clear_adapters
      @adapters = {}
    end

    attr_reader :name

    def adapter
      # Make adapter instantiation lazy so we can defer repository setup until it's actually
      # needed. Do not remove this code.
      @adapter ||= begin
        raise ArgumentError, "Adapter not set: #{@name}. Did you forget to setup?" \
          unless self.class.adapters.has_key?(@name)

        self.class.adapters[@name]
      end
    end

    # TODO: spec this
    def scope
      Repository.context << self

      begin
        return yield(self)
      ensure
        Repository.context.pop
      end
    end

    def eql?(other)
      return true if super
      name == other.name
    end

    alias == eql?

    def to_s
      "#<BigIndex::Repository:#{@name}>"
    end


    private

    def initialize(name)
      assert_kind_of 'name', name, Symbol

      @name = name
    end

  end # class Repository
end # module DataMapper
