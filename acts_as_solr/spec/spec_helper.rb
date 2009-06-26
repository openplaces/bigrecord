require 'pathname'
require 'rubygems'
gem 'rspec', '~>1.2'
require 'spec'

# TODO: Remove this later
class Object; def self.deprecate(*options); end; end

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path

# Require ActiveRecord
require 'active_record'

# Require BigRecord by first checking within the BigRecord project
begin
  require File.join(SPEC_ROOT.parent, "..", "bigrecord", "lib", "big_record")
rescue LoadError
  # If it wasn't found, try requiring via gem.
  gem 'big_record'
  require 'big_record'
end

# Now we can require acts_as_solr
require SPEC_ROOT.parent + "lib/acts_as_solr"

# Now we'll initialize the ORM connection
begin
  require 'connection'
rescue LoadError
  # Default to BigRecord if none was defined.
  require File.join(File.dirname(__FILE__), 'connections', 'bigrecord', 'connection')
  BigRecord::Base.logger.info "No data store defined. Using BigRecord..."
end


# Redefine the Hash class to include two helper methods used only in the specs.
class Hash
  # Helper method to determine if a hash is completely contained within other_hash (order is not important).
  # Matches each key/value pair, and returns false as soon as a mismatch occurs. The other_hash might have
  # more pairs, but those aren't considered.
  #
  #   hash1 = { :key1 => "value1", :key2 => "value2", :key3 => "value3" }
  #
  #   hash2 = { :key1 => "value1", :key2 => "value2", :key3 => "value3", :key4 => "value4" }
  #
  #   hash3 = { :key1 => "value4", :key2 => "value3", :key3 => "value1", :key4 => "value2" }
  #
  #   hash1.subset_of?(hash2) # => true
  #   hash2.subset_of?(hash1) # => false
  #   hash3.subset_of?(hash1) # => false
  #   hash3.subset_of?(hash2) # => false
  #
  def subset_of?(other_hash)
    self.each_pair do |key, value|
      return false if !other_hash.has_key?(key) || !(other_hash[key] == value)
    end

    true
  end

  def superset_of?(other_hash)
    other_hash.subset_of?(self)
  end

end