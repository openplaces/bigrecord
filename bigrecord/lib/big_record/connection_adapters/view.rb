module BigRecord
  module ConnectionAdapters

    # = Named Views
    #
    # To use column-oriented databases more efficiently, it helps to know
    # exactly which specific columns are required for a query.
    #
    # For example, supposing we're designing two queries:
    # (A) used on the front page of a website.
    # (B) used on the summary page for a particular item.
    #
    # Since we know these two queries will be serving up different information,
    # we can also figure out which columns are needed by each. In general,
    # query (A) would only require a subset of columns of (B). This
    # functionality is analogous to the SQL command "SELECT column1,column2 ..."
    # for defining specific columns to query for.
    #
    # Named views are defined in models by using the {BigRecord::Base.view}
    # macro like in the following example:
    #
    #   class Book < BigRecord::Base
    #     column :title,   :string
    #     column :author,             :string
    #     column :description,        :string
    #     column :links,              :string,  :collection => true
    #
    #     view :front_page, :title, :author
    #     view :summary_page, :title, :author, :description
    #
    #     # Override default if you don't want all columns returned
    #     view :default, :title, :author, :description
    #   end
    #
    # Now, whenever you work with a Book record, it will only returned the
    # columns you specify according to the view option you pass. i.e.
    #
    #   >> Book.find(:first, :view => :front_page)
    #   => #<Book id: "2e13f182-1085-495e-9841-fe5c84ae9992", attribute:title: "Hello Thar", attribute:author: "Greg">
    #
    #   >> Book.find(:first, :view => :summary_page)
    #   => #<Book id: "2e13f182-1085-495e-9841-fe5c84ae9992", attribute:description: "Masterpiece!", attribute:title: "Hello Thar", attribute:author: "Greg">
    #
    #   >> Book.find(:first, :view => :default)
    #   => #<Book id: "2e13f182-1085-495e-9841-fe5c84ae9992", attribute:description: "Masterpiece!", attribute:title: "Hello Thar", attribute:links: ["link1", "link2", "link3", "link4"], attribute:author: "Greg">
    #
    # Any attributes that were not loaded in as part of the view will be
    # lazy-loaded on request. This is very inefficient and should be avoided
    # at all costs! It's better to load more columns in, than to have
    # any attributes lazy-loaded afterwards.
    #
    # Note: A Bigrecord model will return all the columns within the default
    # column family (when :view option is left blank, for example).
    # You can override the :default name view to change this behaviour.
    #
    # It's also possible to define specific columns to load at query time.
    # To do this, you can just pass an array of columns to the :columns
    # option of the find method and it will return only those attributes:
    #
    #   >> Book.find(:first, :columns => [:author, :description])
    #   => #<Book id: "2e13f182-1085-495e-9841-fe5c84ae9992", attribute:description: "Masterpiece!", attribute:author: "Greg">
    #
    # Once again, any attributes not loaded during query time will be
    # lazy-loaded on request.
    #
    class View
      attr_reader :name, :owner

      def initialize(name, column_names, owner)
        @name = name.to_s
        @column_names = column_names ? column_names.collect{|c| c.to_s} : nil
        @owner = owner
      end

      # Return the column objects associated with this view. By default the views 'all' and 'default' return every column.
      def columns
        if @column_names
          columns = []

          # First match against fully named columns, e.g. 'attribute:name'
          @column_names.each{|cn| columns << owner.columns_hash[cn] if owner.columns_hash.has_key?(cn)}

          # Now match against aliases if the number of columns found previously do not
          # match the expected @columns_names size, i.e. there's still some missing.
          if columns.size != @column_names.size
            columns_left = @column_names - columns.map{|column| column.name}
            owner.columns_hash.each { |name,column| columns << column if columns_left.include?(column.alias) }
          end

          columns
        else
          owner.columns
        end
      end

      # Return the name of the column objects associated with this view. By default the views 'all' and 'default' return every column.
      def column_names
        @column_names || owner.column_names
      end
    end
  end
end
