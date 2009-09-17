spec = Gem::Specification.new do |s|
  s.name = 'bigindex'
  s.author = "openplaces.org"
  s.email = "bigrecord@openplaces.org"
  s.homepage = "http://www.bigrecord.org"
  s.platform = Gem::Platform::RUBY
  s.summary = "A Rails plugin that drops into models and provides indexing functionality."
  s.description = "A Rails plugin that drops into models and provides indexing functionality. Uses an adapter/repository pattern inspired by Datamapper to abstract the actual indexer used in the background, and exposes the model to a simple indexing API."
  s.has_rdoc = true
  s.version = "0.0.1"

  s.add_dependency "solr", ">= 0.0.7"
  s.add_dependency "uuidtools", ">= 2.0.0"
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
  package.need_tar = true
  package.need_zip = true
end