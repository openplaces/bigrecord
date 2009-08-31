#--
# Copyright (c) 2009 openplaces
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

unless defined?(ActiveSupport)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activesupport/lib")
    require 'active_support'
  rescue LoadError
    require 'rubygems'
    gem 'activesupport'
    require 'active_support'
  end
end

unless defined?(ActiveRecord)
  begin
    $:.unshift(File.dirname(__FILE__) + "/../../activerecord/lib")
    require 'active_record'
  rescue LoadError
    require 'rubygems'
    gem 'activerecord'
    require 'active_record'
  end
end

# FIXME: this shouldn't be required
# require 'active_record/fixtures'

require 'big_record/routing_ext'
require 'big_record/abstract_base'
require 'big_record/base'
require 'big_record/embedded'
require 'big_record/validations'
require 'big_record/callbacks'
require 'big_record/ar_reflection'
require 'big_record/br_reflection'
require 'big_record/ar_associations'
require 'big_record/br_associations'
require 'big_record/timestamp'
require 'big_record/attribute_methods'
require 'big_record/embedded_associations/association_proxy'
require 'big_record/dynamic_schema'
require 'big_record/deletion'
require 'big_record/family_span_columns'
require 'big_record/migration'
require 'big_record/connection_adapters'
require 'big_record/fixtures'

# Add support for collections to tag builders
require 'big_record/action_view_extensions'

BigRecord::Base.class_eval do
  include BigRecord::Validations
  include BigRecord::Callbacks
  include BigRecord::Timestamp
  include BigRecord::ArAssociations
  include BigRecord::BrAssociations
  include BigRecord::ArReflection
  include BigRecord::BrReflection
  include BigRecord::AttributeMethods
  include BigRecord::DynamicSchema
  include BigRecord::Deletion
  include BigRecord::FamilySpanColumns
end

BigRecord::Embedded.class_eval do
  include BigRecord::Validations
  include BigRecord::Callbacks
  include BigRecord::Timestamp
  include BigRecord::ArAssociations
  include BigRecord::BrAssociations
  include BigRecord::ArReflection
  include BigRecord::BrReflection
  include BigRecord::AttributeMethods
  include BigRecord::DynamicSchema
end

# Mixin the BigRecord associations with ActiveRecord
ActiveRecord::Base.class_eval do
  include BigRecord::BrAssociations
  include BigRecord::BrReflection
end

# Patch to call the validation of the embedded objects to HbaseRecord::Base instances.
BigRecord::Base.class_eval do
  validate :validate_embeddeds

  def validate_embeddeds
    attributes.each do |k, v|
      if v.kind_of?(BigRecord::Embedded)
        errors.add(k, "is invalid: @errors=#{v.errors.full_messages.inspect}") unless v.valid?
      elsif v.is_a?(Array) and v.first.kind_of?(BigRecord::Embedded)
        v.each_with_index do |item, i|
          next if item.blank?
          unless item.valid?
            errors.add(k, "is invalid. The item ##{i} in the collection has the following errors: @errors=#{item.errors.full_messages.inspect}")
          end
        end
      end
    end
  end
end
