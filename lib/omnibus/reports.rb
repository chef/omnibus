#
# Copyright 2012-2014 Chef Software, Inc.
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

    PADDING = 3

    # Determine how wide a column should be, taking into account both
    # the column name as well as all data in that column.  If no data
    # will be stored in the column, the width is 0 (i.e., nothing
    # should be printed, not even the column header)
    def column_width(items, column_name)
      widest_item = items.max { |a, b| a.size <=> b.size }
      if widest_item
        widest = (widest_item.size >= column_name.size) ? widest_item : column_name
        widest.size + PADDING
      else
        0
      end
    end

    def non_nil_values(hashes, selector_key)
      hashes.map { |v| v[selector_key] }.compact
    end

    def pretty_version_map(project)
      out = ""
      version_map = project.library.version_map

      # Pull out data to print out
      versions = non_nil_values(version_map.values, :version)
      guids = non_nil_values(version_map.values, :version_guid)

      # We only want the versions that have truly been overridden;
      # because we want to output a column only if something was
      # overridden, but nothing if no packages were changed
      overridden_versions = non_nil_values(version_map.values.select { |v| v[:overridden] }, :default_version)

      # Determine how wide the printed table columns need to be
      name_width = column_width(version_map.keys, "Component")
      version_width = column_width(versions, "Installed Version")
      guid_width = column_width(guids, "Version GUID")
      override_width = column_width(overridden_versions, "Overridden From")

      total_width = name_width + version_width + guid_width + override_width
      divider = "-" * total_width

      # Print out the column headers
      out << "Component".ljust(name_width)
      out << "Installed Version".ljust(version_width)
      out << "Version GUID".ljust(guid_width)
      # Only print out column if something was overridden
      out << "Overridden From".ljust(override_width) if override_width > 0
      out << "\n"
      out << divider << "\n"

      # Print out the table body
      version_map.keys.sort.each do |name|
        version = version_map[name][:version]
        version_guid = version_map[name][:version_guid]

        default_version = version_map[name][:default_version]
        overridden = version_map[name][:overridden]

        out << "#{name}".ljust(name_width)
        out << version.to_s.ljust(version_width)
        out << version_guid.to_s.ljust(guid_width) if version_guid
        # Only print out column if something was overridden
        out << default_version.ljust(override_width) if overridden
        out << "\n"
      end
      out
    end
  end
end
