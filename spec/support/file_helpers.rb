require 'fileutils'

module Omnibus
  module RSpec
    module FileHelpers
      def create_directory(*paths)
        FileUtils.mkdir_p(File.join(*paths))
      end

      def remove_directory(*paths)
        FileUtils.rm_rf(File.join(*paths))
      end
      alias_method :remove_file, :remove_directory

      def create_file(*paths, &block)
        path = File.join(*paths)
        create_directory(File.dirname(path))

        if block
          File.open(path, 'wb') do |f|
            f.write(block.call)
          end
        else
          FileUtils.touch(path)
        end
      end

      def create_link(a, b)
        FileUtils.ln_s(a, b)
      end
    end
  end
end
