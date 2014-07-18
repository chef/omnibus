module Omnibus
  module RSpec
    module PathHelpers
      def software_path(name)
        File.join(data_path, 'software', "#{name}.rb")
      end

      def overrides_path(name)
        File.join(data_path, 'overrides', "#{name}.overrides")
      end

      def project_path(name)
        File.join(data_path, 'projects', "#{name}.rb")
      end

      def asset_path(name)
        File.join(data_path, 'assets', name)
      end

      def complicated_path
        File.join(data_path, 'complicated')
      end

      def fixtures_path
        File.expand_path('../fixtures', __FILE__)
      end

      def tmp_path
        File.expand_path('../../tmp', __FILE__)
      end

      private

      def data_path
        @data_path ||= File.expand_path('../../data', __FILE__)
      end
    end
  end
end
