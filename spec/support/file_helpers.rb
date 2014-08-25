module Omnibus
  module RSpec
    module FileHelpers
      def create_directory(*paths)
        path = File.join(*paths)
        FileUtils.mkdir_p(path)
        path
      end

      def remove_directory(*paths)
        path = File.join(*paths)
        FileUtils.rm_rf(path)
        path
      end

      def copy_file(source, destination)
        FileUtils.cp(source, destination)
        destination
      end

      def remove_file(*paths)
        path = File.join(*paths)
        FileUtils.rm_f(path)
        path
      end

      def create_file(*paths, &block)
        path = File.join(*paths)

        FileUtils.mkdir_p(File.dirname(path))

        if block
          File.open(path, 'wb') { |f| f.write(block.call) }
        else
          FileUtils.touch(path)
        end

        path
      end

      def create_link(a, b)
        FileUtils.ln_s(a, b)
      end
    end
  end
end
