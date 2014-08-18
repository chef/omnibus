require 'fileutils'

module Omnibus
  module RSpec
    module FileHelpers
      include Omnibus::Util

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
