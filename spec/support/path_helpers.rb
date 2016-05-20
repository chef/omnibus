module Omnibus
  module RSpec
    module PathHelpers
      def fixture_path(*pieces)
        File.join(fixtures_path, *pieces)
      end

      def tmp_path
        File.expand_path("../../tmp", __FILE__)
      end

      private

      def fixtures_path
        File.expand_path("../../fixtures", __FILE__)
      end
    end
  end
end
