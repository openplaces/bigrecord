module ActsAsSolr #:nodoc:
  
  module CommonMethods
    
    # Converts field types into Solr types
    def get_solr_field_type(field_type)
      if field_type.is_a?(Symbol)
        case field_type
          when :float then                return "f"
          when :integer then              return "i"
          when :boolean then              return "b"
          when :string then               return "s"
          when :date then                 return "d"
          when :range_float then          return "rf"
          when :range_integer then        return "ri"
          when :ngrams then               return "ngrams"
          when :autocomplete then         return "auto"
          when :lowercase then            return "lc"
          when :exact_match then          return "em"
          when :geo then                  return "geo"
          when :text then                 return "t"
          when :text_not_stored then      return "t_ns"
          when :text_not_indexed then     return "t_ni"
          when :integer_array then        return "i_mv"
          when :text_array then           return "t_mv"
          when :text_array_not_stored then return "t_mv_ns"
          when :float_array then          return "f_mv"
          when :boolean_array then        return "b_mv"
          when :date_array then           return "d_mv"
          when :string_array then         return "s_mv"
          when :range_integer_array then  return "ri_mv"
          when :range_float_array then    return "rf_mv"
          when :ngrams_array then         return "ngrams_mv"
          when :autocomplete_array then   return "auto_mv"
          when :lowercase_array then      return "lc_mv"
          when :exact_match_array then    return "em_mv"
        else
          raise "Unknown field_type symbol: #{field_type}"
        end
      elsif field_type.is_a?(String)
        return field_type
      else
        raise "Unknown field_type class: #{field_type.class}: #{field_type}"
      end
    end

    # Sets a default value when value being set is nil.
    def set_value_if_nil(field_type)
      case field_type
        when "b", :boolean then                        return "false"
        when "s", "t", "t_ns", "t_ni", "d", "ngrams", "auto", "lc", "em", :date, :string, :text, :text_not_stored, :text_not_indexed, :ngrams, :autocomplete, :lowercase, :exact_match then return ""
        when "f", "rf", :float, :range_float then      return 0.00
        when "i", "ri", :integer, :range_integer then  return 0
        when "f_mv", "i_mv", "b_mv", "s_mv", "t_mv", "t_mv_ns", "d_mv", "rf_mv", "ri_mv", "ngrams_mv", "auto_mv", "lc_mv", "em_mv", "geo" then return []
        when :float_array, :integer_array, :boolean_array, :string_array, :date_array, :range_float_array, :range_integer_array, :ngrams_array, :text_array, :text_array_not_stored, :autocomplete_array, :lowercase_array, :exact_match_array, :geo then return []
      else
        return nil
      end
    end
    
    # Sends an add command to Solr
    def solr_add(add_xml)
      solr_execute(Solr::Request::AddDocument.new(add_xml))
    end
    
    # Sends the delete command to Solr
    def solr_delete(solr_ids)
      solr_execute(Solr::Request::Delete.new(:id => solr_ids))
    end
    
    def solr_delete_query(query)
      solr_execute(Solr::Request::Delete.new(:query => query))
    end
    
    # Sends the commit command to Solr
    def solr_commit
      solr_execute(Solr::Request::Commit.new)
    end

    # Optimizes the Solr index. Solr says:
    # 
    # Optimizations can take nearly ten minutes to run. 
    # We are presuming optimizations should be run once following large 
    # batch-like updates to the collection and/or once a day.
    # 
    # One of the solutions for this would be to create a cron job that 
    # runs every day at midnight and optmizes the index:
    #   0 0 * * * /your_rails_dir/script/runner -e production "Model.solr_optimize"
    # 
    def solr_optimize
      solr_execute(Solr::Request::Optimize.new)
    end
    
    # Returns the id for the given instance
    def record_id(object)
      object.id
    end
    
  protected
  
    def solr_log(str, name = nil)
      if block_given?
        if logger and logger.level <= Logger::INFO
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
      return unless logger

      logger.debug(
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
    
  end
  
end
