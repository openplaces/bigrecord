require 'fileutils'

puts "[Bigrecord] Copying example config file to your RAILS_ROOT...\n"

config_dir = File.join(RAILS_ROOT, "config")
source = File.join(File.dirname(__FILE__), "examples", "bigrecord.yml")
target = File.join(config_dir, "bigrecord.yml")
alternate_target = File.join(config_dir, "bigrecord.yml.sample")

migration_dir = File.join(RAILS_ROOT, "db", "bigrecord_migrate")

if !File.exist?(target)
  FileUtils.cp(source, target)
else
  puts "[Bigrecord] RAILS_ROOT/config/bigrecord.yml file already exists. Copying it as bigrecord.yml.sample for reference."
  FileUtils.cp(source, alternate_target)
end

unless File.exist?(migration_dir)
  puts "[Bigrecord] Migration folder not found at \"#{migration_dir}\" Creating now..."
  FileUtils.mkdir_p(migration_dir)
end
