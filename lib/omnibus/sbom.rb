require_relative "config"
module Omnibus
  class SBOM
    include Logging

    class << self
      def generate_sbom(project, tool_name)
        tool_name ||= "syft"
        log.info(log_key) { "Generating SBOM ..." }

        begin
          install_syft(project)
          check_syft_version(project)
          list_files(project)
          generate_sbom_file(project, tool_name)
          display_sbom(project)

          log.info(log_key) { "SBOM generated successfully" }
        rescue => e
          log.error(log_key) { "SBOM generation failed: #{e.message}" }
          raise
        end
      end

      private

      def install_syft(project)
        log.info(log_key) { "Installing syft..." }
        project.shellout!("curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin")
        log.info(log_key) { "Syft installed successfully" }
      end

      def check_syft_version(project)
        log.info(log_key) { "Checking syft version..." }
        project.shellout!("syft version")
        log.info(log_key) { "Syft version checked successfully" }
      end

      def list_files(project)
        log.info(log_key) { "Listing files..." }
        project.shellout!("ls -l #{project.default_root}")
        # project.shellout!("ls -l #{project.default_root}/#{project.name}")
        project.shellout!("ls -l #{Omnibus::Config.project_root}/../")
        project.shellout!("ls -l #{Omnibus::Config.project_root}")
        log.info(log_key) { "Files listed successfully" }
      end

      def generate_sbom_file(project, tool_name)
        log.info(log_key) { "Generating SBOM file..." }
        # project.shellout!("#{tool_name} packages #{project.default_root}/#{project.name} --output spdx-json > sbom.json")
        project.shellout!("#{tool_name} #{Omnibus::Config.project_root}/../Gemfile.lock --output spdx-json > sbom-2.json")
        log.info(log_key) { "SBOM file generated successfully" }
      end

      def display_sbom(project)
        log.info(log_key) { "Displaying SBOM..." }
        project.shellout!("cat sbom-2.json")
        log.info(log_key) { "SBOM displayed successfully" }
      end
    end
  end
end
