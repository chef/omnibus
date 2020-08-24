module Omnibus
  module RSpec
    module PathHelpers
      def fixture_path(*pieces)
        File.join(fixtures_path, *pieces)
      end

      def tmp_path
        File.expand_path("../tmp", __dir__)
      end

      private

      def fixtures_path
        File.expand_path("../fixtures", __dir__)
      end
    end
  end
end
