begin
  require 'yard'

  desc 'Generate documentation for BigRecord.'
  YARD::Rake::YardocTask.new do |t|
    t.files = %w(- doc/*.rdoc)
    t.options = ["--title", "BigRecord Documentation"]
  end

  desc 'Generate documentation for BigRecord.'
  task :rdoc => :yardoc
rescue LoadError
  puts "yard not available. Install it with: sudo gem install yard"
end
