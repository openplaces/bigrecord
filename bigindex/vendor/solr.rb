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

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Solr; end

require File.dirname(__FILE__) + '/solr/exception'
require File.dirname(__FILE__) + '/solr/request'
require File.dirname(__FILE__) + '/solr/connection'
require File.dirname(__FILE__) + '/solr/response'
require File.dirname(__FILE__) + '/solr/util'
require File.dirname(__FILE__) + '/solr/xml'
require File.dirname(__FILE__) + '/solr/importer'
require File.dirname(__FILE__) + '/solr/indexer'
require File.dirname(__FILE__) + '/solr/commit_scheduler'
require File.dirname(__FILE__) + '/solr/field_entry'
