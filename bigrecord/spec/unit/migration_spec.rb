require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigRecord::Migration do

  before(:each) do
    @migrations_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib", "migrations"))
    @migration_files = Dir["#{@migrations_path}/[0-9]*_*.rb"]

    # It doesn't matter whether the adapter works for this spec, so we'll mock it
    @mock_connection = mock(BigRecord::ConnectionAdapters::AbstractAdapter, :null_object => true)
    @mock_connection.stub!(:supports_ddl_transactions?).and_return(false)

    # Replace BigRecord::Base.connection to always return the mock_connection
    BigRecord::Base.stub!(:connection).and_return(@mock_connection)

    # We don't want it outputting to stdout
    BigRecord::Migration.verbose = false
  end

  describe "class methods and initialization" do

    it "#proper_table_name should return the corresponding table name for the data store (with different arguments types)" do
      # Check that it works with a symbol, BigRecord model, or string.
      BigRecord::Migrator.proper_table_name(:animals).should == "animals"
      BigRecord::Migrator.proper_table_name(Animal).should == "animals"
      BigRecord::Migrator.proper_table_name("animals").should == "animals"
    end

    it "#get_all_versions should query from the data store" do
      @mock_connection.should_receive(:get_all_schema_versions).and_return(["version1"])

      BigRecord::Migrator.get_all_versions.should == ["version1"]
    end

    it "should initialize the migrator given a directory of migration files" do
      # Assuming that the adapter supports migrations
      @mock_connection.should_receive(:supports_migrations?).and_return(true)

      # Setting up the migrator will initialize the schema migration table
      @mock_connection.should_receive(:initialize_schema_migrations_table)

      # Initializing the migrator
      migrator = BigRecord::Migrator.new(:up, @migrations_path)

      # Now assuming that the adapter doesn't supports migrations
      @mock_connection.should_receive(:supports_migrations?).and_return(false)

      # Setting up the migrator should not initialize the schema migration table
      @mock_connection.should_not_receive(:initialize_schema_migrations_table)

      lambda{
        migrator = BigRecord::Migrator.new(:up, @migrations_path)
      }.should raise_error(StandardError)
    end

  end

  describe "migrator methods" do

    before(:each) do
      # Setting up the migrator will initialize the schema migration table
      @mock_connection.should_receive(:initialize_schema_migrations_table)

      # Initializing the migrator
      @migrator = BigRecord::Migrator.new(:up, @migrations_path)
    end

    it "should show all the pending migrations" do
      # And request all the schema versions currently within the data store
      @mock_connection.should_receive(:get_all_schema_versions).and_return([])

      # Verify that our migrations are listed as pending
      @migration_files.each do |migration_file|
        @migrator.pending_migrations.map(&:filename).should include(migration_file)
      end
    end

    it "should run the migrations and update the schema migration table in the data store" do
      # And request all the schema versions currently within the data store
      @mock_connection.should_receive(:get_all_schema_versions).and_return([])

      # The data store will be updated once for each migration file
      @mock_connection.should_receive(:update).exactly(@migration_files.size).times.and_return(true)
      result = @migrator.migrate

      # The pending migrations should now be listed in the migrated #migrated method and removed from #pending_migrations
      result.size.should == @migration_files.size
      @migrator.migrated.size.should == @migration_files.size
      @migrator.pending_migrations.should be_empty
    end

  end

end