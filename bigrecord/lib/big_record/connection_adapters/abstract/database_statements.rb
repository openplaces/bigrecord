module BigRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      # Inserts the given fixture into the table. Overridden in adapters that require
      # something beyond a simple insert (eg. Oracle).
      def insert_fixture(fixture, table_name)
        # execute "INSERT INTO #{quote_table_name(table_name)} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
        attributes = fixture.to_hash.dup
        id = attributes.delete("id")
        raise ArgumentError, "the id is missing" unless id
        update(table_name, id, attributes, Time.now.to_bigrecord_timestamp)
      end
    end
  end
end
