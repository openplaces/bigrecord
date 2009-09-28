begin
  require 'jeweler'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "bigrecord"
    gemspec.authors = ["openplaces.org"]
    gemspec.email = "bigrecord@openplaces.org"
    gemspec.homepage = "http://www.bigrecord.org"
    gemspec.summary = "Object mapper for supporting column-oriented data stores (supports #{DATA_STORES.join(" ")}) in Ruby on Rails."
    gemspec.description = "BigRecord is built from ActiveRecord, and intended to seamlessly integrate into your Ruby on Rails applications."

    gemspec.add_dependency "uuidtools", ">= 2.0.0"
    gemspec.add_dependency "openplaces-bigrecord-driver"
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
