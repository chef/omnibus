module Omnibus
  module Overrides

    # Parses a file of override information into a hash.
    #
    # Each line of the file must be of the form
    #
    # <package_name> <version>
    #
    # where the two pieces of data are separated by whitespace.
    def self.parse_file(file)
      File.readlines(file).inject({}) do |acc, line|
        info = line.split
        raise "Invalid overrides line: '#{line.chomp}'" if info.count != 2
        package, version = info
        acc[package] = version
        acc
      end
    end

  end
end
