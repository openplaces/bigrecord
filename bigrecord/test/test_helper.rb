$:.unshift(File.dirname(__FILE__) + '/../lib')

class Object; def self.deprecate(*options); end
end

require 'rubygems'
require 'ruby-debug'

require 'test/unit'
require 'big_record'
#require 'hbase_record/fixtures'

begin
  require 'connection'
rescue LoadError
  puts "requires connection file"
end

Dir.glob( File.join(File.dirname(__FILE__), "models","*.rb") ).each do |model|
  require model
end

class Test::Unit::TestCase

  #self.fixture_path = File.dirname(__FILE__) + "/fixtures/"

  # def create_hbase_fixtures(*table_names, &block)
  #   Fixtures.create_hbase_fixtures(File.dirname(__FILE__) + "/fixtures/", table_names, {}, &block)
  # end

  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #self.hbase_use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  #self.hbase_use_instantiated_fixtures  = false
end
