require 'big_index'

def config_file
  "#{RAILS_ROOT}/config/bigindex.yml"
end

def full_config
  YAML::load(File.open(config_file))
end

def symbolize_keys(h)
  config = {}

  h.each do |k, v|
    if k == 'port'
      config[k.to_sym] = v.to_i
    elsif k == 'adapter' && v == 'postgresql'
      config[k.to_sym] = 'postgres'
    elsif v.is_a?(Hash)
      config[k.to_sym] = symbolize_keys(v)
    else
      config[k.to_sym] = v
    end
  end

  config
end

def get_config_for_environment
  if hash = full_config[RAILS_ENV]
    symbolize_keys(hash)
  elsif hash = full_config[RAILS_ENV.to_sym]
    hash
  else
    raise ArgumentError, "missing environment '#{RAILS_ENV}' in config file #{config_file}"
  end
end


BigIndex.setup(:default, get_config_for_environment) unless get_config_for_environment.empty?