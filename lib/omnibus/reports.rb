module Omnibus

  module Reports
    extend self

    def pretty_version_map
      out = ""
      version_map = Omnibus.library.version_map
      width = version_map.keys.max {|a,b| a.size <=> b.size }.size + 3
      version_map.keys.sort.each do |name|
        version = version_map[name]
        out << "#{name}:".ljust(width) << version.to_s << "\n"
      end
      out
    end

  end


end
