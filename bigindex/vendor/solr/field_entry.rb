# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'solr/xml'
require 'time'

module Solr

class FieldEntry
  VALID_PARAMS = [:boost]
  attr_accessor :name
  attr_accessor :value
  attr_accessor :boost

  # Accepts an optional <tt>:boost</tt> parameter, used to boost the relevance of a particular field.
  def initialize(params)
    @boost = params[:boost]
    name_key = (params.keys - VALID_PARAMS).first
    @name, @value = name_key.to_s, params[name_key]
    # Convert any Time values into UTC/XML schema format (which Solr requires).
    @value = @value.respond_to?(:utc) ? @value.utc.xmlschema : @value.to_s
  end

  def to_xml
    e = Solr::XML::Element.new 'field'
    e.attributes['name'] = @name
    e.attributes['boost'] = @boost.to_s if @boost

#     #must unescape the xml special characters or else they are
#     #escaped twice (once by ERB::Util.html_escape and once by libxml)
#    clean_value = nil
#    if @value
#      clean_value = @value.gsub(/\"/, "\\\"")#.gsub(/&amp;/, "&")
##      clean_value = clean_value.gsub(/&lt;/, "<")
##      clean_value = clean_value.gsub(/&gt;/, ">")
##      clean_value = clean_value.gsub(/&quot;/, "\"")
##      clean_value = clean_value.gsub(/&apos;/, "'")
#    end

    e.text = @value
    return e
  end

end
end
