require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'

# Mixin a reflection method that returns self. Useful for generating
# form fields for primitive objects. It must be mixed in Object because
# the class for the type :boolean is Object.
class Object
  def reflect_value
    self
  end
end

module ActionView #:nodoc:
  module Helpers
    class InstanceTag #:nodoc:

      def to_date_select_tag(options = {})
        date_or_time_select(options.merge(:discard_hour => true))
      end

      def to_time_select_tag(options = {})
        date_or_time_select options.merge(:discard_year => true, :discard_month => true)
      end

      def to_datetime_select_tag(options = {})
        date_or_time_select options
      end

      def to_label_tag(text = nil, options = {})
        name_and_id = options.dup
        add_default_name_and_id(name_and_id)
        options["for"] = name_and_id["id"]
        content = (text.blank? ? nil : text.to_s) || method_name.humanize
        content_tag("label", content, options)
      end

      def to_input_field_tag(field_type, options = {})
        options = options.stringify_keys
        options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        if field_type == "hidden"
          options.delete("size")
        end
        options["type"] = field_type
        options["value"] ||= value_before_type_cast(object, options) unless field_type == "file"
        add_default_name_and_id(options)
        tag("input", options)
      end

      def to_radio_button_tag(tag_value, options = {})
        options = DEFAULT_RADIO_OPTIONS.merge(options.stringify_keys)
        options["type"]     = "radio"
        options["value"]    = tag_value
        if options.has_key?("checked")
          cv = options.delete "checked"
          checked = cv == true || cv == "checked"
        else
          checked = self.class.radio_button_checked?(value(object, options), tag_value)
        end
        options["checked"]  = "checked" if checked
        pretty_tag_value    = tag_value.to_s.gsub(/\s/, "_").gsub(/\W/, "").downcase
        options["id"]     ||= defined?(@auto_index) ?
          "#{@object_name}_#{@auto_index}_#{@method_name}_#{pretty_tag_value}" :
          "#{@object_name}_#{@method_name}_#{pretty_tag_value}"
        add_default_name_and_id(options)
        tag("input", options)
      end

      def to_text_area_tag(options = {})
        options = DEFAULT_TEXT_AREA_OPTIONS.merge(options.stringify_keys)
        add_default_name_and_id(options)

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
        end
        content_tag("textarea", html_escape(options.delete('value') || value_before_type_cast(object, options)), options)
      end

      def to_check_box_tag(options = {}, checked_value = "1", unchecked_value = "0")
        options = options.stringify_keys
        options["type"]     = "checkbox"
        options["value"]    = checked_value
        if options.has_key?("checked")
          cv = options.delete "checked"
          checked = cv == true || cv == "checked"
        else
          checked = self.class.check_box_checked?(value(object, options), checked_value)
        end
        options["checked"] = "checked" if checked
        add_default_name_and_id(options)
        tag("input", options) << tag("input", "name" => options["name"], "type" => "hidden", "value" => options['disabled'] && checked ? checked_value : unchecked_value)
      end

      def to_date_tag()
        defaults = DEFAULT_DATE_OPTIONS.dup
        date     = value(object, options) || Date.today
        options  = Proc.new { |position| defaults.merge(:prefix => "#{@object_name}[#{@method_name}(#{position}i)]") }
        html_day_select(date, options.call(3)) +
        html_month_select(date, options.call(2)) +
        html_year_select(date, options.call(1))
      end

      def to_select_tag(choices, options, html_options)
        html_options = html_options.stringify_keys

        # Ugly hack... how come selectors don't have the same signature as the other ones
        html_options["index"] = options[:index]

        add_default_name_and_id(html_options)
        value = value(object, html_options)
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        content_tag("select", add_options(options_for_select(choices, selected_value), options, selected_value), html_options)
      end

      def to_content_tag(tag_name, options = {})
        content_tag(tag_name, value(object, options), options)
      end

      def object
        @object || (@template_object.instance_variable_get("@#{@object_name}") rescue nil)
      end

      def value(object, options={})
        self.class.value(object, @method_name, options)
      end

      def value_before_type_cast(object, options={})
        self.class.value_before_type_cast(object, @method_name, options)
      end

      class << self
        def value(object, method_name, options={})
          options = options.stringify_keys
          v = object.send method_name unless object.nil?
          (options["index"] and v.is_a?(Array)) ? v[options["index"]] : v
        end

        def value_before_type_cast(object, method_name, options={})
          unless object.nil?
            options = options.stringify_keys
            v = object.respond_to?(method_name + "_before_type_cast") ?
            object.send(method_name + "_before_type_cast") :
            object.send(method_name)
            (options["index"] and v.is_a?(Array)) ? v[options["index"]] : v
          end
        end

      end

      private
        def date_or_time_select(options)
          defaults = { :discard_type => true }
          options  = defaults.merge(options)

          datetime = value(object, options)
          datetime ||= default_time_from_options(options[:default]) unless options[:include_blank]

          position = { :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5, :second => 6 }

          order = (options[:order] ||= [:year, :month, :day])

          # Discard explicit and implicit by not being included in the :order
          discard = {}
          discard[:year]   = true if options[:discard_year] or !order.include?(:year)
          discard[:month]  = true if options[:discard_month] or !order.include?(:month)
          discard[:day]    = true if options[:discard_day] or discard[:month] or !order.include?(:day)
          discard[:hour]   = true if options[:discard_hour]
          discard[:minute] = true if options[:discard_minute] or discard[:hour]
          discard[:second] = true unless options[:include_seconds] && !discard[:minute]

          # If the day is hidden and the month is visible, the day should be set to the 1st so all month choices are valid
          # (otherwise it could be 31 and february wouldn't be a valid date)
          if datetime && discard[:day] && !discard[:month]
            datetime = datetime.change(:day => 1)
          end

          # Maintain valid dates by including hidden fields for discarded elements
          [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }

          # Ensure proper ordering of :hour, :minute and :second
          [:hour, :minute, :second].each { |o| order.delete(o); order.push(o) }

          date_or_time_select = ''
          order.reverse.each do |param|
            # Send hidden fields for discarded elements once output has started
            # This ensures AR can reconstruct valid dates using ParseDate
            next if discard[param] && date_or_time_select.empty?

            date_or_time_select.insert(0, self.send("select_#{param}", datetime, options_with_prefix(position[param], options.merge(:use_hidden => discard[param]))))
            date_or_time_select.insert(0,
              case param
                when :hour then (discard[:year] && discard[:day] ? "" : " &mdash; ")
                when :minute then " : "
                when :second then options[:include_seconds] ? " : " : ""
                else ""
              end)

          end

          date_or_time_select
        end

        def options_with_prefix(position, options)
          prefix = "#{@object_name}"
          if options[:index]
            prefix << "[#{options[:index]}]"
          elsif @auto_index
            prefix << "[#{@auto_index}]"
          end
          options.merge(:prefix => "#{prefix}[#{@method_name}(#{position}i)]")
        end

        def tag_name
          "#{@object_name}[#{@method_name}]"
        end

        def tag_name_with_index(index)
          "#{@object_name}[#{index}][#{@method_name}]"
        end

        def tag_id
          "#{sanitized_object_name}_#{@method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{@method_name}"
        end

        def sanitized_object_name
          @object_name.gsub(/[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
        end

    end

    class FormBuilder
      # Override to allow the use of an index
      def fields_for(record_or_name_or_array, *args, &block)
        if options.has_key?(:index)
          index = "[#{options[:index]}]"
        elsif defined?(@auto_index)
          self.object_name = @object_name.to_s.sub(/\[\]$/,"")
          index = "[#{@auto_index}]"
        else
          index = ""
        end

        case record_or_name_or_array
        when String, Symbol
          name = "#{object_name}#{index}[#{record_or_name_or_array}]"
        when Array
          object = record_or_name_or_array.last
          name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
          args.unshift(object)
        else
          object = record_or_name_or_array
          name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
          args.unshift(object)
        end

        @template.fields_for(name, *args, &block)
      end
    end
  end

end
