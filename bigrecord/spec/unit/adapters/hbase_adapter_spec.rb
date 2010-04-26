require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'adapter_shared_spec'))

describe BigRecord::ConnectionAdapters::HbaseAdapter do

  before do
    # Make sure the connection is defined in spec/connections/bigrecord.yml
    @adapter = BigRecord::Base.connection
  end

  it_should_behave_like 'a BigRecord Adapter'

end
