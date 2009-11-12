module BigRecord

  # = Embedded Records
  #
  # Since a single column in a column-oriented database is perfectly suited
  # to handle large amounts of data, BigRecord gives you the option to store
  # entire records within a single column of another {BigRecord::Base} record.
  #
  # These are known as Embedded records, and they behave similarly to
  # {BigRecord::Base} objects, except that their data is physically stored
  # within another {BigRecord::Base} record, and they don't exist unless
  # associated with one. Furthermore, they don't possess any find or querying
  # functionality.
  #
  # So what are the benefits of Embedded records?
  # * Cleaner organization of models
  # * Avoids the need to create entire tables and associations for models that
  #   exist only in the context of another model.
  # * Allows more complicated functionality to be encompassed within an
  #   embedded record, instead of in a parent model.
  #
  # All of this has been very abstract so far, therefore examples are in order.
  #
  # == Examples
  #
  # Let's say we start off with the following arbitrarily created models:
  #
  # app/model/book.rb:
  #   class Book < BigRecord::Base
  #     column :title,       :string
  #     column :author,      :string
  #     column :description, :string
  #   end
  #
  # app/model/company.rb:
  #   class Company < BigRecord::Base
  #     column :name,        :string
  #     column :address,     :string
  #     column :description, :string
  #   end
  #
  # Now, let's say we want the ability to create and associate weblinks
  # with each of these models. This is a trivial modification if all we do is
  # create a new column in each model called "weblink" (or something similar),
  # and have a string that stores a URL.
  #
  # However, what if we wanted these weblinks to have more metadata attached
  # and more complex functionality added to it? Then our only choice is to
  # create a new model called WebLink (for example), with its own table, set of
  # attributes and methods. Then we have our Book and Company models associate
  # to these newly created WebLink models, giving us something like this:
  #
  # app/model/web_link.rb:
  #   class WebLink < BigRecord::Base
  #     column :name,         :string
  #     column :url,          :string
  #     column :description,  :string
  #     column :submitted_by, :string
  #     column :book_id,      :string
  #     column :company_id,   :string
  #
  #     # Could use a polymorphic association here, of course.
  #     belongs_to_bigrecord :book, :foreign_key => "attribute:book_id"
  #     belongs_to_bigrecord :company, :foreign_key => "attribute:company_id"
  #
  #     # other methods ...
  #   end
  #
  # and likewise an association to WebLink from the Book and Company models.
  #
  # Now notice the problem here? A simple concept like adding a WebLink with
  # some metadata has increased the model logic and created some unnecessary
  # associations. In this situation, a WebLink doesn't need to exist except
  # when associated to a certain model. Therefore this association should be
  # implicit somehow.
  #
  # Enter Embedded records. We will now instead define WebLink as follows:
  #
  # app/model/web_link.rb:
  #   class WebLink < BigRecord::Embedded
  #     column :name,         :string
  #     column :url,          :string
  #     column :description,  :string
  #     column :submitted_by, :string
  #
  #     # other methods ...
  #   end
  #
  # And modify our Base records like so:
  #
  # app/model/book.rb:
  #   class Book < BigRecord::Base
  #     column :title,       :string
  #     column :author,      :string
  #     column :description, :string
  #     column :web_link,    'WebLink'
  #   end
  #
  # app/model/company.rb:
  #   class Company < BigRecord::Base
  #     column :name,        :string
  #     column :address,     :string
  #     column :description, :string
  #     column :web_link,    'WebLink'
  #   end
  #
  # Now we can encompass any WebLink specific attributes and methods within
  # the WebLink embedded class, and use them with any other Base model.
  #
  # To use WebLink now, we treat it as though it were a regular model, except
  # that we don't execute saves on it. For example:
  #
  #   >> amazon_link = WebLink.new(:name => "Amazon Link to Book", :url => "http://amazon.com/some/book", :description => "Amazon sells this book for cheap!")
  #   => #<WebLink created_at: "2009-11-12 17:11:57", name: "Amazon Link to Book", url: "http://amazon.com/some/book", description: "Amazon sells this book for cheap!", submitted_by: nil, id: "2b619a68-e462-475d-8e04-01ba2aace11a">
  #   >> amazon_link.save
  #   BigRecord::NotImplemented: BigRecord::NotImplemented
  #   # => [...]
  #   >> book = Book.find(:first)
  #   # => [...]
  #   >> book.web_link = amazon_link
  #   >> book.save
  #
  # Now any subsequent access to that book object we just saved to will have
  # a WebLink record available with it.
  #
  class Embedded < AbstractBase

    def initialize(attrs = nil)
      super
      # Regenerate the id unless it's already there
      # (i.e. we're instantiating an existing property)
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
