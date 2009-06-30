module Solr

  class Base
    attr_reader :configurations
    attr_reader :logger

    # URL and Shard methods ====================================

    def solr_url
      @solr_url ||= @configurations[:solr_url]
    end

    def solr_shards_urls
      @solr_shards_url ||= (@configurations[:shards] || [])
    end

    def solr_shards
      @solr_shards ||= solr_shards_urls.each{|url| url.gsub("http://", "")}
    end

    def solr_using_shards?
      !solr_shards.empty?
    end


    # Solr execute and find methods ====================================

    def solr_execute(request, shard_url = nil)
      if solr_using_shards?
        # Handle batch update
        if request.is_a?(Solr::Request::AddDocument) and request.docs.size > 1 and !shard_url
          # Split the request into several ones if it must be sent to different shards
          sub_requests = {}
          request.docs.each do |doc|
            url = shard_url_for(doc['pk_s'])
            if sub_requests.has_key?(url)
              sub_requests[url].add_doc(doc)
            else
              sub_requests[url] = Solr::Request::AddDocument.new(doc)
            end
          end
          # Recursive execution of the sub queries
          logger.debug "Splitted batch update to send it to the following shards: #{sub_requests.keys.inspect}" if sub_requests.size > 1
          sub_requests.each{|url, sub_request| solr_execute(sub_request, url)} and return

        # Handle delete by query by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Delete) and request.query and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return

        # Handle commit by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Commit) and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return

        # Handle optimize by sending the request to all the shards
        elsif request.is_a?(Solr::Request::Optimize) and !shard_url
          solr_shards_urls.each do |url|
            solr_execute(request, url)
          end
          return
        end

        url = shard_url ? shard_url : random_shard_url
        request.shards = solr_shards if request.is_a?(Solr::Request::Select)

        logger.debug "#{request.class} using shard #{url}"

      else
        url = solr_url
      end

      connection = Solr::Connection.new(url)
      result = nil

      message = request.respond_to?(:to_hash) ? "/#{request.handler} #{request.to_hash.inspect}" : request.to_s

      solr_log message do
        result = connection.send(request)
      end
      result
    end


    def initialize(options, logger = nil)
      raise ArgumentError, "Adapter: #{options[:adapter]} is not for Solr" unless options[:adapter] == "solr"

      @configurations = options
      @logger = logger
    end

    protected

      # Logging related methods. Only works if a logger was defined in initialize()

      def solr_log(str, name = nil)
        if block_given?
          if @logger and @logger.level <= Logger::INFO
            result = nil
            seconds = Benchmark.realtime { result = yield }
            solr_log_info(str, name, seconds)
            result
          else
            yield
          end
        else
          solr_log_info(str, name, 0)
          nil
        end
      rescue Exception => e
        # Log message and raise exception.
        # Set last_verfication to 0, so that connection gets verified
        # upon reentering the request loop
        @last_verification = 0
        message = "#{e.class.name}: #{e.message}: #{str}"
        solr_log_info(message, name, 0)
        raise message
      end

      def solr_log_info(str, name, runtime)
        return unless @logger

        @logger.debug(
          solr_format_log_entry(
            "#{name.nil? ? "Solr" : name} (#{sprintf("%f", runtime)})",
            str.gsub(/ +/, " ")
          )
        )
      end

      @@row_even = true

      def solr_format_log_entry(message, dump = nil)
        if ActiveRecord::Base.colorize_logging
          if @@row_even
            @@row_even = false
            message_color, dump_color = "4;36;1", "0;1"
          else
            @@row_even = true
            message_color, dump_color = "4;35;1", "0"
          end

          log_entry = "  \e[#{message_color}m#{message}\e[0m   "
          log_entry << "\e[#{dump_color}m%#{String === dump ? 's' : 'p'}\e[0m" % dump if dump
          log_entry
        else
          "%s  %s" % [message, dump]
        end
      end

  end # class Base

end # module Solr