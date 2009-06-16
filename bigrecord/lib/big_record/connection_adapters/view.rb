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
          @column_names.collect{|cn| owner.columns_hash[cn]}
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
