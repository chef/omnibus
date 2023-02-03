require "spec_helper"

module Omnibus
  describe Buildkite do

    let(:ami_id) { "ami-1234ab5678cd9ef01" }
    let(:hostname) { "CHF-V-ABC-DE000.local" }
    let(:docker_version) { "20.0.0" }
    let(:docker_image) { "artifactory-url.com/release-type/base-platform" }
    let(:docker_command) { "docker build . -f images/omnibus_toolchain_containers/platform/Dockerfile -t artifactory-url.com/release-type/omnibus-toolchain-platform -t chefes/omnibus-toolchain-platform --build-arg OS_IMAGE=#{docker_image}" }

    subject(:buildkite_metadata) { described_class }

    before(:each) do
      clear_defaults
    end

    describe "#ami_id" do
      it "returns the ami_id if one is found" do
        with_ami_id
        expect(buildkite_metadata.ami_id).to eq(ami_id)
      end

      it "returns the unknown if nothing present" do
        expect(buildkite_metadata.ami_id).to eq("unknown")
      end
    end

    describe "#hostname" do
      it "returns the hostname if one is found" do
        with_hostname
        expect(buildkite_metadata.hostname).to eq(hostname)
      end

      it "returns the unknown if nothing present" do
        expect(buildkite_metadata.hostname).to eq("unknown")
      end
    end

    describe "#is_docker_build" do
      it "returns true if docker metadata is present" do
        with_docker
        expect(buildkite_metadata.is_docker_build).to eq(true)
      end

      it "returns false if docker metadata is missing" do
        expect(buildkite_metadata.is_docker_build).to eq(false)
      end
    end

    describe "#docker_version" do
      it "returns the docker version if one is found" do
        with_docker
        expect(buildkite_metadata.docker_version).to eq(docker_version)
      end

      it "returns nothing if docker version is missing" do
        expect(buildkite_metadata.docker_version).to be_nil
      end
    end

    describe "#docker_image" do
      it "returns the docker image id if one is found" do
        with_docker
        expect(buildkite_metadata.docker_image).to eq(docker_image)
      end

      it "returns nothing if docker image id is missing" do
        expect(buildkite_metadata.docker_image).to be_nil
      end
    end

    describe "#omnibus_version" do
      it "returns the omnibus_version if one is found" do
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end
    end

    describe "#to_hash" do
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

    context "platform builds on linux" do
      it "uses docker" do
        with_ami_id
        with_docker

        expect(buildkite_metadata.ami_id).to eq(ami_id)
        expect(buildkite_metadata.is_docker_build).to eq(true)
        expect(buildkite_metadata.docker_version).to eq(docker_version)
        expect(buildkite_metadata.docker_image).to eq(docker_image)
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end

      it "does not use docker" do
        with_ami_id

        expect(buildkite_metadata.ami_id).to eq(ami_id)
        expect(buildkite_metadata.is_docker_build).to eq(false)
        expect(buildkite_metadata.docker_version).to be_nil
        expect(buildkite_metadata.docker_image).to be_nil
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end
    end

    context "platform builds on windows" do
      it "uses docker" do
        with_ami_id
        with_docker

        expect(buildkite_metadata.ami_id).to eq(ami_id)
        expect(buildkite_metadata.is_docker_build).to eq(true)
        expect(buildkite_metadata.docker_version).to eq(docker_version)
        expect(buildkite_metadata.docker_image).to eq(docker_image)
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end

      it "does not use docker" do
        with_ami_id

        expect(buildkite_metadata.ami_id).to eq(ami_id)
        expect(buildkite_metadata.is_docker_build).to eq(false)
        expect(buildkite_metadata.docker_version).to be_nil
        expect(buildkite_metadata.docker_image).to be_nil
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end
    end

    describe "platform builds on macOS" do
      it "uses docker" do
        with_hostname
        with_docker

        expect(buildkite_metadata.hostname).to eq(hostname)
        expect(buildkite_metadata.is_docker_build).to eq(true)
        expect(buildkite_metadata.docker_version).to eq(docker_version)
        expect(buildkite_metadata.docker_image).to eq(docker_image)
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end

      it "does not use docker" do
        with_hostname

        expect(buildkite_metadata.hostname).to eq(hostname)
        expect(buildkite_metadata.is_docker_build).to eq(false)
        expect(buildkite_metadata.docker_version).to be_nil
        expect(buildkite_metadata.docker_image).to be_nil
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
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