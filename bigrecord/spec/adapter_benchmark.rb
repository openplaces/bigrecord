# This benchmark was created to give a relative measure of performance
# between different adapters, e.g. Bigrecord Driver vs Stargate.
#
# This is not meant to be a benchmark of real world performance.
#
# To use it, run the command:
#   > ruby adapter_benchmark.rb [hbase|hbase_brd]
#

require 'rubygems'
require 'benchmark'
require 'ruby-debug'

bigrecord_driver_path = File.expand_path(File.dirname(__FILE__)+'/../../bigrecord-driver/lib')
$:.unshift(bigrecord_driver_path) if File.directory?(bigrecord_driver_path) && !$:.include?(bigrecord_driver_path)

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
require SPEC_ROOT + '/../lib/big_record'

BigRecord::Base.configurations = YAML::load(File.open(File.join(File.dirname(__FILE__), "connections", "bigrecord.yml")))
BigRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "benchmark.log"))

environment = (ARGV.pop || "hbase")
BigRecord::Base.establish_connection(environment)
BigRecord::Base.logger.info "Connecting to #{environment} data store (#{BigRecord::Base.configurations.inspect})"

require 'lib/book'

Book.delete_all
record_ids = []

# Benchmark the creation process
Benchmark.bm do |x|
  x.report("Creating 1000 records") do
    record_ids = 1000.times.collect do |i|
      Book.create(:title => "Book_#{i}", :description => "Book description", :author => "Some Author").id
    end
  end
end

# Reading in those records created previously
Benchmark.bm do |x|
  x.report("Reading 1000 records") do
    record_ids.each do |id|
      Book.find(id)
    end
  end
end

# Benchmark the scanner functionality
Benchmark.bm do |x|
  x.report('find(:all)x10') do
    10.times do |x|
      Book.find(:all)
    end
  end
end

Book.delete_all
