require "spec_helper"

module Omnibus
  describe BuildkiteMetadata do

    let(:ami_id) { "ami-1234ab5678cd9ef01" }
    let(:hostname) { "CHF-V-ABC-DE000.local" }
    let(:docker_version) { "20.0.0" }
    let(:docker_image) { "artifactory-url.com/release-type/base-platform" }
    let(:docker_command) { "docker build . -f images/omnibus_toolchain_containers/platform/Dockerfile -t artifactory-url.com/release-type/omnibus-toolchain-platform -t chefes/omnibus-toolchain-platform --build-arg OS_IMAGE=#{docker_image}" }

    subject(:buildkite_metadata) { described_class }

    describe "#ami_id" do
      it "returns the ami_id if present" do
        without_ami_id_and_hostname
        with_ami_id
        expect(buildkite_metadata.ami_id).to eq(ami_id)
      end

      it "returns the hostname as ami_id if present" do
        without_ami_id_and_hostname
        with_hostname
        expect(buildkite_metadata.ami_id).to eq(hostname)
      end

      it "returns the unknown if nothing present" do
        without_ami_id_and_hostname
        expect(buildkite_metadata.ami_id).to eq("unknown")
      end
    end

    describe "#is_docker_build" do
      it "returns true if docker metadata is present" do
        with_docker
        expect(buildkite_metadata.is_docker_build).to eq(true)
      end

      it "returns false if docker metadata is missing" do
        without_docker
        expect(buildkite_metadata.is_docker_build).to eq(false)
      end
    end

    describe "#docker_version" do
      it "returns the docker version if present" do
        with_docker
        expect(buildkite_metadata.docker_version).to eq(docker_version)
      end

      it "returns nothing if docker version is missing" do
        without_docker
        expect(buildkite_metadata.docker_version).to be_nil
      end
    end

    describe "#docker_image" do
      it "returns the docker image id if present" do
        with_docker
        expect(buildkite_metadata.docker_image).to eq(docker_image)
      end

      it "returns nothing if docker image id is missing" do
        without_docker
        expect(buildkite_metadata.docker_image).to be_nil
      end
    end

    describe "#omnibus_version" do
      it "returns the omnibus_version if present" do
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end
    end

    context "platform builds on unix" do
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
        without_docker

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
        without_docker

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

        expect(buildkite_metadata.ami_id).to eq(hostname)
        expect(buildkite_metadata.is_docker_build).to eq(true)
        expect(buildkite_metadata.docker_version).to eq(docker_version)
        expect(buildkite_metadata.docker_image).to eq(docker_image)
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end

      it "does not use docker" do
        with_hostname
        without_docker

        expect(buildkite_metadata.ami_id).to eq(hostname)
        expect(buildkite_metadata.is_docker_build).to eq(false)
        expect(buildkite_metadata.docker_version).to be_nil
        expect(buildkite_metadata.docker_image).to be_nil
        expect(buildkite_metadata.omnibus_version).to eq(Omnibus::VERSION)
      end
    end

    def without_ami_id_and_hostname
      stub_env("BUILDKITE_AGENT_META_DATA_AWS_AMI_ID", nil)
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

    def without_docker
      stub_env("BUILDKITE_AGENT_META_DATA_DOCKER", nil)
      stub_env("BUILDKITE_COMMAND", nil)
    end
  end
end