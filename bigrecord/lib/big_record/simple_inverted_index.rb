module BigRecord

  class Base

    after_save    :create_simple_index
    after_destroy :remove_simple_index

    def self.simple_index(term)
      @inverted_index = SimpleInvertedIndex.new(table_name, connection) if @inverted_index.blank?
      @inverted_index_terms = [] if @inverted_index_terms.blank?

      if new.respond_to?(term.to_s)
        @inverted_index_terms << term.to_s unless @inverted_index_terms.include?(term.to_s)

        define_finder(term.to_s)
      else
        raise ArgumentError, "#{term} is not a valid method of #{self}"
      end
    end

    def self.inverted_index
      @inverted_index
    end

    def self.inverted_index_terms
      @inverted_index_terms ||= []
    end

  private

    def create_simple_index
      unless self.class.inverted_index.blank?
        self.class.inverted_index_terms.each do |term|
          self.class.inverted_index.add_entry(term, send(term), id)
        end
      end
    end

    def remove_simple_index
      unless self.class.inverted_index.blank?
        self.class.inverted_index_terms.each do |term|
          self.class.inverted_index.remove_entry(term, send(term), id)
        end
      end
    end

    def self.define_finder(finder_name)
      class_eval <<-end_eval
        def self.find_all_by_#{finder_name}(user_query, options={})
          options[:count] = options.delete(:limit)
          ids = inverted_index.get_results("#{finder_name}", user_query, options)

          find(ids)
        end

        def self.find_by_#{finder_name}(user_query, options={})
          id = inverted_index.get_results("#{finder_name}", user_query, :count => 1).first

          id.blank? ? nil : find(id)
        end
      end_eval
    end

  end

  class SimpleInvertedIndex

    TABLE_NAME = "index"
    DEFAULT_VALUE = "1"

    attr_accessor :index_name
    attr_reader   :connection

    def initialize(name, conn)
      @index_name = name
      @connection = conn
    end

    def generate_key(term, value)
      "#{@index_name}/#{term}/#{value}"
    end

    def add_entry(term, value, result)
      key = generate_key(term, value)

      @connection.update_raw(TABLE_NAME, key, {result.to_s => DEFAULT_VALUE}, nil)
    end

    def remove_entry(term, value, result = nil)
      key = generate_key(term, value)

      if result
        @connection.raw_connection.remove(TABLE_NAME, key, result)
      else
        @connection.delete(TABLE_NAME, key)
      end
    end

    def get_results(term, value, options = {})
      key = generate_key(term, value)

      if options[:offset].nil? && options[:count].nil?
        @connection.get_raw(TABLE_NAME, key, nil).keys || []
      else
        options[:start] = options.delete(:offset)

        @connection.raw_connection.get(TABLE_NAME, key, options).keys || []
      end
    end

  end

end

