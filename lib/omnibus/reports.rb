#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus

  module Reports
    extend self

    def pretty_version_map(project)
      out = ""
      version_map = Omnibus.library.version_map(project)
      width = version_map.keys.max {|a,b| a.size <=> b.size }.size + 3
      version_map.keys.sort.each do |name|
        version = version_map[name]
        out << "#{name}:".ljust(width) << version.to_s << "\n"
      end
      out
    end

  end


end
