desc 'Generate documentation for Bigindex.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Bigindex'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('../README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end