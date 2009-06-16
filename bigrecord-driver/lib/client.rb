require 'rubygems'
require 'activesupport' 
require 'set'
require 'drb'

module BigRecord
  class Client
    
    def initialize(config={}) # :nodoc:
      config = config.symbolize_keys
      config[:master]       ||= 'localhost:60000'
      config[:regionserver] ||= 'regionserver:60020'
      config[:drb_host]     ||= 'localhost'
      config[:drb_port]     ||= 40000
      
      @config = config

      DRb.start_service
      begin
        @server = DRbObject.new(nil, "druby://#{@config[:drb_host]}:#{@config[:drb_port]}")
      rescue DRb::DRbConnError
        raise BigDB::ConnectionError, "Failed to connect to the DRb server (jruby) " +
                                      "at #{@config[:drb_host]}:#{@config[:drb_port]}."
      end
      @server.configure(:master => @config[:master], :regionserver => @config[:regionserver])
    end
    
    # Delegate the methods to the server
    def method_missing(method, *args)
      @server.send(method, *args)
    end
    
    def respond_to?(method)
      super
    end
    
  end
end
