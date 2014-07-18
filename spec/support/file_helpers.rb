require 'fileutils'

module Omnibus
  module RSpec
    module FileHelpers
      def create_directory(path)
        FileUtils.mkdir_p(path)
      end

      def remove_directory(path)
        FileUtils.rm_rf(path)
      end
      alias_method :remove_file, :remove_directory

      def create_file(path, contents = nil)
        create_directory(File.dirname(path))

        if contents.nil?
          FileUtils.touch(path)
        else
          File.open(path, 'wb') do |f|
            f.write(contents)
          end
        end
      end

      def create_link(a, b)
        FileUtils.ln_s(a, b)
      end
    end
  end
end
