require "spec_helper"

module Omnibus
  describe BuildSystemMetadata do

    let(:ami_id) { "ami-1234ab5678cd9ef01" }
    let(:hostname) { "CHF-V-ABC-DE000.local" }
    let(:docker_version) { "20.0.0" }
    let(:docker_image) { "artifactory-url.com/release-type/base-platform" }
    let(:docker_command) { "docker build . -f images/omnibus_toolchain_containers/platform/Dockerfile -t artifactory-url.com/release-type/omnibus-toolchain-platform -t chefes/omnibus-toolchain-platform --build-arg OS_IMAGE=#{docker_image}" }

    subject(:buildkite_metadata) { Omnibus::Buildkite }

    describe "#to_hash" do
      context "builds occur on buildkite" do

        before(:each) do
          clear_defaults
        end

        it "returns an ami_id if one is found" do
          with_ami_id
          expect(buildkite_metadata.to_hash[:ami_id]).to eq(ami_id)
        end

        it "returns an hostname if one is found" do
          with_hostname
          expect(buildkite_metadata.to_hash[:hostname]).to eq(hostname)
        end

        it "returns is_docker_build if one is found" do
          with_docker
          expect(buildkite_metadata.to_hash[:is_docker_build]).to eq(true)
        end

        it "returns a docker_version if one is found" do
          with_docker
          expect(buildkite_metadata.to_hash[:docker_version]).to eq(docker_version)
        end

        it "returns a docker_image if one is found" do
          with_docker
          expect(buildkite_metadata.to_hash[:docker_image]).to eq(docker_image)
        end

        it "returns an omnibus_version if one is found" do
          expect(buildkite_metadata.to_hash[:omnibus_version]).to eq(Omnibus::VERSION)
        end

      end
    end

    def with_ami_id
      stub_env("BUILDKITE_AGENT_META_DATA_AWS_AMI_ID", ami_id)
    end

    def with_hostname
      stub_env("BUILDKITE_AGENT_META_DATA_HOSTNAME", hostname)
    end

    def with_docker
      stub_env("BUILDKITE_AGENT_META_DATA_DOCKER", docker_version)
      stub_env("BUILDKITE_COMMAND", docker_command)
    end

    def clear_defaults
      without_ami_id_and_hostname
      without_docker
    end

    def without_ami_id_and_hostname
      stub_env("BUILDKITE_AGENT_META_DATA_AWS_AMI_ID", nil)
      stub_env("BUILDKITE_AGENT_META_DATA_HOSTNAME", nil)
    end

    def without_docker
      stub_env("BUILDKITE_AGENT_META_DATA_DOCKER", nil)
      stub_env("BUILDKITE_COMMAND", nil)
    end

  end
end