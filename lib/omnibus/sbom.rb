module Omnibus
  class SBOM
    include Logging

    class << self
      def generate_sbom(project, tool_name)
        tool_name = "syft" if tool_name.nil?
        log.info(log_key) { "Generating SBOM ..." }

        begin
          # Install Syft
          project.shellout!("curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin")

          # check for syft version
          project.shellout!("syft version")

          # list the files in the default root
          project.shellout!("ls -l #{project.default_root}")

          # Generate SBOM
          project.shellout!("#{tool_name} packages #{project.default_root} --output spdx-json > sbom.json")

          # display the SBOM
          project.shellout!("cat sbom.json")

          log.info(log_key) { "SBOM generated successfully" }
        rescue => e
          log.error(log_key) { "SBOM generation failed: #{e.message}" }
          raise
        end
      end
    end
  end
end
