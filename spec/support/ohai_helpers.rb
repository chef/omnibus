require "fauxhai"
require "omnibus/ohai"

module Omnibus
  module RSpec
    module OhaiHelpers
      #
      # Stub Ohai with the given data.
      #
      def stub_ohai(options = {}, &block)
        ohai = Mash.from_hash(Fauxhai.mock(options, &block).data)
        allow(Ohai).to receive(:ohai).and_return(ohai)

        if options[:platform] && options[:platform] == "windows"
          # If we asked for Windows, we should also specify that magical
          # +File::ALT_SEPARATOR+ variable
          stub_const("File::ALT_SEPARATOR", '\\')
          # And don't actually perform expand_path because otherwise,
          # C:/foo will turn into "/Users/foo/bar/baz/C:/foo" on non-windows
          # and /foo will turn into "C:/foo" on windows.
          # Since most paths in our tests are unixy-paths, we'll turn off
          # expand_path just on windows by default.
          if windows? && options[:enable_expand_path] != false
            allow(File).to receive(:expand_path) { |arg| arg }
          end
        end
      end
    end
  end
end
