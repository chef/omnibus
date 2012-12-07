module Omnibus
  module Overrides

    DEFAULT_OVERRIDE_FILE_NAME = "omnibus.overrides"

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

    # Return the full path to an overrides file, or +nil+ if no such
    # file exists.
    def self.resolve_override_file
      file = ENV['OMNIBUS_OVERRIDE_FILE'] || DEFAULT_OVERRIDE_FILE_NAME
      path = File.expand_path(file)
      path if File.exist?(path)
    end
    
  end
end

