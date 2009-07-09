describe "a BigRecord Adapter", :shared => true do

  %w{adapter_name supports_migrations?}.each do |meth|
    it "should have a ##{meth} method" do
      @adapter.should respond_to(meth.intern)
    end
  end

  describe "with connection management" do
    %w{active? reconnect! disconnect!}.each do |meth|
      it "should have a ##{meth} method" do
        @adapter.should respond_to(meth.intern)
      end
    end
  end

  describe "with data store statements" do
    %w{update_raw update get_raw get get_columns_raw get_columns get_consecutive_rows_raw get_consecutive_rows delete delete_all}.each do |meth|
      it "should have a ##{meth} method" do
        @adapter.should respond_to(meth.intern)
      end
    end
  end

  describe "with schema statements" do
    %w{table_exists? create_table drop_table}.each do |meth|
      it "should have a ##{meth} method" do
        @adapter.should respond_to(meth.intern)
      end
    end

    it "should have the methods needed for migrations if supports_migrations? is true" do
      if @adapter.supports_migrations?
        %w{initialize_schema_migrations_table get_all_schema_versions add_column_family remove_column_family modify_column_family}.each do |meth|
          @adapter.should respond_to(meth.intern)
        end
      end
    end
  end

  describe "timestamp functionality" do
    it "should use the default Time.to_bigrecord_timestamp or implement it's own method" do
      Time.now.should respond_to(:to_bigrecord_timestamp)
      Time.should respond_to(:from_bigrecord_timestamp)

      Time.now.to_bigrecord_timestamp.should_not be_nil
      Time.from_bigrecord_timestamp(Time.now.to_bigrecord_timestamp).should_not be_nil
    end
  end

end
