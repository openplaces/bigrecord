require 'big_index'

BigIndex.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/bigindex.yml"))
