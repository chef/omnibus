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
        FileUtils.rm(path) if File.exist?(path)

        if block
          File.open(path, "wb") { |f| f.write(yield) }
        else
          FileUtils.touch(path)
        end

        path
      end

      def create_link(src, dest)
        # Windows has no symlinks. Documentation seems to suggest that
        # ln will create hard-links - so attempt to elicit the behavior
        # we want using hard-links.  If your test happens to fail even
        # with this, consider what semantics you actually wish to have
        # on windows and refactor your test or code.
        if windows?
          FileUtils.ln(src, dest) unless File.exist?(dest)
        else
          FileUtils.ln_s(src, dest) unless File.exist?(dest)
        end
      end
    end
  end
end
