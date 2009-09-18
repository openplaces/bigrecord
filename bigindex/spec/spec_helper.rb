require 'pathname'
require 'rubygems'
gem 'rspec', '~>1.2'
require 'spec'

# TODO: Remove this later
class Object; def self.deprecate(*options); end; end

#NotImplementedError = Spec::Example::NotYetImplementedError

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path

# Require ActiveRecord
begin
  require 'active_record'
rescue LoadError
  # do nothing
end

# Require BigRecord by first checking within the BigRecord project
begin
  require File.join(SPEC_ROOT.parent, "..", "bigrecord", "lib", "big_record")
rescue LoadError
  # If it wasn't found, try requiring via gem.
  # begin
  #   gem 'big_record'
  #   require 'big_record'
  # rescue
  #   # do nothing
  # end
end

# Now we can require BigIndex
require SPEC_ROOT.parent + "lib/big_index"

CONFIGURATION_FILE_OPTIONS = YAML.load(File.new(File.dirname(__FILE__) + '/connections/bigindex.yml')).freeze
BigIndex.configurations = CONFIGURATION_FILE_OPTIONS

# Now we'll initialize the ORM connection
begin
  require 'connection'
rescue LoadError
  # Default to BigRecord if none was defined.
  require File.join(File.dirname(__FILE__), 'connections', 'bigrecord', 'connection')
  BigRecord::Base.logger.info "No data store defined. Using BigRecord..."
end
