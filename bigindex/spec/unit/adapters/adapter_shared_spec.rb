describe "a BigIndex Adapter", :shared => true do

  %w( adapter_name process_index_batch drop_index
      find_values_by_index find_by_index find_ids_by_index ).each do |meth|
    it "should have a ##{meth} method" do
      @adapter.should respond_to(meth.intern.to_sym)
    end
  end

end