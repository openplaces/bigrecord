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
    %w{create_table drop_table}.each do |meth|
      it "should have a ##{meth} method" do
        @adapter.should respond_to(meth.intern)
      end
    end
  end

end
