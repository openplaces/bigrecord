require 'rubygems'
require 'activesupport' 
require 'set'
require 'drb'

module BigRecordDriver
  class Client
    
    def initialize(config={}) # :nodoc:
      config = config.symbolize_keys
      config[:drb_host]     ||= '127.0.0.1'
      config[:drb_port]     ||= 40000
      
      @config = config

      DRb.start_service('druby://127.0.0.1:0')
      begin
        @server = DRbObject.new(nil, "druby://#{@config[:drb_host]}:#{@config[:drb_port]}")
      rescue DRb::DRbConnError
        raise ConnectionError, "Failed to connect to the DRb server (jruby) " +
                                      "at #{@config[:drb_host]}:#{@config[:drb_port]}."
      end
      @server.configure(@config)
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
