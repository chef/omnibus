require 'pp'

module Omnibus
  module Overrides
    DEFAULT_OVERRIDE_FILE_NAME = 'omnibus.overrides'

    # Parses a file of override information into a Hash.
    #
    # Each line of the file must be of the form
    #
    #
    #     <package_name> <version>
    #
    # where the two pieces of data are separated by whitespace.
    #
    # @param file [String] the path to an overrides file
    # @return [Hash, nil]
    def self.parse_file(file)
      if file
        File.readlines(file).reduce({}) do |acc, line|
          info = line.split

          unless info.count == 2
            fail ArgumentError, "Invalid overrides line: '#{line.chomp}'"
          end

          package, version = info

          if acc[package]
            fail ArgumentError, "Multiple overrides present for '#{package}' in overrides file #{file}!"
          end

          acc[package] = version
          acc
        end
      else
        nil
      end
    end

    # Return the full path to an overrides file, or +nil+ if no such
    # file exists.
    def self.resolve_override_file
      file = ENV['OMNIBUS_OVERRIDE_FILE'] || DEFAULT_OVERRIDE_FILE_NAME
      path = File.expand_path(file)
      File.exist?(path) ? path : nil
    end

    # Return a hash of override information.  If no such information
    # can be found, the hash will be empty
    #
    # @return [Hash]
    def self.overrides
      file = resolve_override_file
      overrides = parse_file(file)

      if overrides
        puts '********************************************************************************'
        puts "Using Overrides from #{Omnibus::Overrides.resolve_override_file}"
        pp overrides
        puts '********************************************************************************'
      end

      overrides || {}
    end
  end
end
