require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'abstract_base_spec'))

describe BigRecord::Base do
  it_should_behave_like "BigRecord::AbstractBase"
end