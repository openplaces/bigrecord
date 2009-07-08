require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'adapter_shared_spec'))

describe BigIndex::Adapters::SolrAdapter do

  before do
    @adapter = BigIndex::Adapters::SolrAdapter.new("test", {:adapter => "solr"})
  end

  it_should_behave_like "a BigIndex Adapter"

  it "should return the right #adapter_name" do
    @adapter.adapter_name.should == 'solr'
  end

end