module BigRecord
  module ConnectionAdapters
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
