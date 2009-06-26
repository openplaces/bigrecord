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

require 'rexml/xpath'

module Solr
  module Response

class Ping < Solr::Response::Xml

  def initialize(xml)
    super(xml)
    @ok = REXML::XPath.first(@doc, "//[@name='status'][.='OK']") ? true : false
  end

  # returns true or false depending on whether the ping
  # was successful or not
  def ok?
    @ok
  end

end

  end
end
