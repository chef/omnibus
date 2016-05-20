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

        # If we asked for Windows, we should also specify that magical
        # +File::ALT_SEPARATOR+ variable
        if options[:platform] && options[:platform] == "windows"
          stub_const("File::ALT_SEPARATOR", '\\')
        end
      end
    end
  end
end
