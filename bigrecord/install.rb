require 'fileutils'

puts "[Bigrecord] Copying example config file to your RAILS_ROOT...\n"

config_dir = File.join(RAILS_ROOT, "config")
source = File.join(File.dirname(__FILE__), "examples", "bigrecord.yml")
target = File.join(config_dir, "bigrecord.yml")
alternate_target = File.join(config_dir, "bigrecord.yml.sample")

if !File.exist?(target)
  FileUtils.cp(source, target)
else
  puts "[Bigrecord] RAILS_ROOT/config/bigrecord.yml file already exists. Copying it as bigrecord.yml.sample for reference."
  FileUtils.cp(source, alternate_target)
end
