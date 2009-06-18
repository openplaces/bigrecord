# The following overrides are required because we use strings as ids and it's
# possible that these strings are not clean. The default implementation
# escapes them with URI.escape() but its' not good. e.g. '&' becomes &amp; instead of %26
module ActionController
  module Routing
    class PathSegment
      def interpolation_chunk(value_code = "#{local_name}")
        "\#{CGI.escape(#{value_code}.to_s)}"
      end

      class Result
        def self.new_escaped(strings)
          new strings.collect {|str| CGI.unescape(str)}
        end
      end
    end

    class DynamicSegment
      def interpolation_chunk(value_code = "#{local_name}")
        "\#{CGI.escape(#{value_code}.to_s)}"
      end

      def match_extraction(next_capture)
        # All non code-related keys (such as :id, :slug) are URI-unescaped as
        # path parameters.
        default_value = default ? default.inspect : nil
        %[
          value = if (m = match[#{next_capture}])
            CGI.unescape(m)
          else
            #{default_value}
          end
          params[:#{key}] = value if value
        ]
      end
    end
  end

  # TODO: Remove this monkey patch once we migrate to rails 2.3. This patch
  # add support for the :as option in map.resources.
  module Resources
    class Resource

      attr_reader :path_segment

      def initialize(entities, options)
        @plural   ||= entities
        @singular ||= options[:singular] || plural.to_s.singularize
        @path_segment = options.delete(:as) || @plural

        @options = options

        arrange_actions
        add_default_actions
        set_prefixes
      end

      def path
        @path ||= "#{path_prefix}/#{path_segment}"
      end

    end
  end

end
