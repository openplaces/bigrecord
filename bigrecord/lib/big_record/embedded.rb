module BigRecord
  class Embedded < AbstractBase

    def initialize(attrs = nil)
      super
      # Regenerate the id unless it's already there (i.e. we're instantiating an existing property)
      @attributes["id"] ||= generate_id
    end

    def connection
      self.class.connection
    end

    def id
      super || (self.id = generate_id)
    end

  protected
    def generate_id
      UUIDTools::UUID.random_create.to_s
    end

  public
    class << self
      def store_primary_key?
        true
      end

      def primary_key
        "id"
      end

      # Borrow the default connection of BigRecord
      def connection
        BigRecord::Base.connection
      end

      def base_class
        (superclass == BigRecord::Embedded) ? self : superclass.base_class
      end

      # Class attribute that holds the name of the embedded type for dispaly
      def pretty_name
        @pretty_name || self.to_s
      end

      def set_pretty_name new_name
        @pretty_name = new_name
      end

      def hide_to_users
        @hide_to_user = true
      end

      def show_to_users?
        !@hide_to_user
      end

      def inherited(child) #:nodoc:
        child.set_pretty_name child.name.split("::").last
        super
      end

      def default_columns
        {primary_key => ConnectionAdapters::Column.new(primary_key, 'string')}
      end

    end

  end
end
