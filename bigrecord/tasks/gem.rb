begin
  require 'jeweler'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "bigrecord"
    gemspec.authors = ["openplaces.org"]
    gemspec.email = "bigrecord@openplaces.org"
    gemspec.homepage = "http://www.bigrecord.org"
    gemspec.summary = "Object mapper for supporting column-oriented data stores (supports #{DATA_STORES.join(" ")}) in Ruby on Rails."
    gemspec.description = "BigRecord is built from ActiveRecord, and intended to seamlessly integrate into your Ruby on Rails applications."
    gemspec.files = FileList["{doc,examples,generators,lib,rails,spec,tasks}/**/*","init.rb","install.rb","Rakefile","VERSION"].to_a
    gemspec.extra_rdoc_files = FileList["doc/**/*","LICENSE","README.rdoc"].to_a

    gemspec.add_development_dependency "rspec"
    gemspec.add_dependency "uuidtools", ">= 2.0.0"
    gemspec.add_dependency "bigrecord-driver"
    gemspec.add_dependency "activesupport"
    gemspec.add_dependency "activerecord"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end
