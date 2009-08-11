spec = Gem::Specification.new do |s|
  s.name = 'bigrecord'
  s.author = "openplaces.org"
  s.email = "bigrecord@openplaces.org"
  s.homepage = "http://www.bigrecord.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "ORM for supporting column-oriented data stores (supports #{DATA_STORES.join(" ")}) in Ruby on Rails."
  s.description = "BigRecord is built from ActiveRecord, and intended to be a nearly seamless integration into your Ruby on Rails applications."
  s.has_rdoc = true
  s.version = "0.1.0"

  s.add_dependency "uuidtools", ">= 2.0.0"
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
  package.need_tar = true
  package.need_zip = true
end