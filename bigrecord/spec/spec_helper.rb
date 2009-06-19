require 'pathname'
require 'rubygems'

gem 'rspec', '~>1.2'
require 'spec'

class Object; def self.deprecate(*options); end; end

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
require SPEC_ROOT.parent + 'lib/big_record'

begin
  require 'connection'
rescue LoadError
  puts "requires connection file"
end

# Load the various helpers for the spec suite
Dir.glob( File.join(File.dirname(__FILE__), "lib", "*.rb") ).each do |model|
  require model
end