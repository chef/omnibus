module Omnibus
  module RSpec
    module EnvHelpers
      #
      # Stub the given environment key.
      #
      # @param [String] key
      # @param [String] value
      #
      def stub_env(key, value)
        unless @__env_already_stubbed__
          allow(ENV).to receive(:[]).and_call_original
          @__env_already_stubbed__ = true
        end

        allow(ENV).to receive(:[]).with(key).and_return(value.to_s)
      end
    end
  end
end
