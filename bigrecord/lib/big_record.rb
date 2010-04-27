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

dir = File.expand_path(File.join(File.dirname(__FILE__), "big_record"))

begin
  require 'active_support'
rescue LoadError
  raise LoadError, "Bigrecord depends on ActiveSupport. Install it with: gem install activesupport"
end

begin
  require 'active_record'
rescue LoadError
  raise LoadError, "Bigrecord depends on ActiveRecord. Install it with: gem install activerecord"
end

require dir + '/routing_ext'
require dir + '/model'
require dir + '/base'
require dir + '/embedded'
require dir + '/validations'
require dir + '/ar_reflection'
require dir + '/br_reflection'
require dir + '/ar_associations'
require dir + '/br_associations'
require dir + '/timestamp'
require dir + '/attribute_methods'
require dir + '/embedded_associations/association_proxy'
require dir + '/dynamic_schema'
require dir + '/deletion'
require dir + '/family_span_columns'
require dir + '/migration'
require dir + '/connection_adapters'
require dir + '/fixtures'
require dir + '/version'

# Add support for collections to tag builders
require dir + '/action_view_extensions'

BigRecord::Base.class_eval do
  include BigRecord::Validations
  include ActiveRecord::Callbacks
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
  include ActiveRecord::Callbacks
  include BigRecord::Timestamp
  include BigRecord::ArAssociations
  include BigRecord::BrAssociations
  include BigRecord::ArReflection
  include BigRecord::BrReflection
  include BigRecord::AttributeMethods
  include BigRecord::DynamicSchema
end

# Mixin the BigRecord associations with ActiveRecord
if defined?(ActiveRecord)
  ActiveRecord::Base.class_eval do
    include BigRecord::BrAssociations
    include BigRecord::BrReflection
  end
end

# Patch to call the validation of the embedded objects to BigRecord::Base instances.
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
