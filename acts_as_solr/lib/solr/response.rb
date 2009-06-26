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

#module Solr; module Response; end; end

require File.dirname(__FILE__) + '/response/base'
require File.dirname(__FILE__) + '/response/xml'
require File.dirname(__FILE__) + '/response/ruby'
require File.dirname(__FILE__) + '/response/ping'
require File.dirname(__FILE__) + '/response/add_document'
require File.dirname(__FILE__) + '/response/standard'
require File.dirname(__FILE__) + '/response/dismax'
require File.dirname(__FILE__) + '/response/commit'
require File.dirname(__FILE__) + '/response/delete'
require File.dirname(__FILE__) + '/response/index_info'
require File.dirname(__FILE__) + '/response/optimize'