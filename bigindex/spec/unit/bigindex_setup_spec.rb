require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe BigIndex do
  def check_for_symbolic_keys(hash)
    hash.should be_a_kind_of(Hash)

    hash.each do |key, value|
      key.should be_a_kind_of(Symbol)

      # If the value is a hash, check that as well
      check_for_symbolic_keys(value) if value.is_a?(Hash)
    end
  end

  before(:each) do
    BigIndex.configurations = CONFIGURATION_FILE_OPTIONS
  end

  it "should respond to the configurations setter and getter" do
    BigIndex.should respond_to(:configurations=)
    BigIndex.should respond_to(:configurations)
  end

  describe "configurations setter and getter" do

    it "#configurations should return a hash" do
      BigIndex.configurations.should be_a_kind_of(Hash)
    end

    it "#configurations= should change the BigIndex settings" do
      original_config = BigIndex.configurations.freeze

      new_config_options = {:temp => {:adapter => "solr", :solr_url => "http://localhost/solr"}}
      new_config = original_config.merge(new_config_options)

      lambda {
        BigIndex.configurations = BigIndex.configurations.merge(new_config_options)
      }.should change(BigIndex, :configurations).from(original_config).to(new_config)
    end

    it "should change all keys to symbols" do
      check_for_symbolic_keys(BigIndex.configurations)

      new_config_options = {"temp" => {"adapter" => "solr", "solr_url" => "http://localhost/solr"}}
      BigIndex.configurations = new_config_options

      check_for_symbolic_keys(BigIndex.configurations)
    end

  end

  describe "repository" do

    it "should be a hash" do
      BigIndex::Repository.adapters.should be_a_kind_of(Hash)
    end

    it "should set up the proper adapters" do
      CONFIGURATION_FILE_OPTIONS.each do |key, value|
        BigIndex::Repository.adapters.should have_key(key.to_sym)

        value.each do |k, v|
          BigIndex::Repository.adapters[key.to_sym].options.should have_key(k.to_sym)
          BigIndex::Repository.adapters[key.to_sym].options[k.to_sym].should == v
        end
      end
    end

  end

end
