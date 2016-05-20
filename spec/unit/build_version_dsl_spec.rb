require "spec_helper"

module Omnibus
  describe BuildVersionDSL do
    let(:subject_with_version) { described_class.new(version_string) }
    let(:subject_with_description) { described_class.new(&description) }

    let(:version_string) { "1.0.0" }
    let(:description) { nil }
    let(:today_string) { Time.now.utc.strftime(Omnibus::BuildVersion::TIMESTAMP_FORMAT) }

    let(:zoo_version) { double("BuildVersion", semver: "5.5.5", custom: "7.7.7", build_start_time: today_string) }
    let(:zoo_software) { double("software", name: "zoo", project_dir: "/etc/zoo", version: "6.6.6") }

    describe "when given nil" do
      it "fails" do
        expect { subject.build_version }.to raise_error(RuntimeError)
      end
    end

    describe "when given a string" do
      it "sets the version to the string" do
        expect(subject_with_version.build_version).to eq("1.0.0")
      end
    end

    describe "when Config.append_timestamp is true" do
      let(:description) do
        proc do
          source(:git, from_dependency: "zoo")
        end
      end

      before { Config.append_timestamp(true) }

      it "appends a timestamp to a static (String) version" do
        expect(subject_with_version.build_version).to eq("1.0.0+#{today_string}")
      end

      it "doesn't append timestamp to something that already looks like it has a timestamp" do
        semver = "1.0.0+#{today_string}.git.222.694b062"
        expect(described_class.new(semver).build_version).to eq("1.0.0+#{today_string}.git.222.694b062")
      end

      it "appends a timestamp to a DSL-built version" do
        allow(BuildVersion).to receive(:new).and_return(BuildVersion.new)
        allow(BuildVersion).to receive(:new).with("/etc/zoo").and_return(zoo_version)
        subject_with_description.resolve(zoo_software)
        expect(subject_with_description.build_version).to eq("5.5.5+#{today_string}")
      end
    end

    describe "when given a :git source" do
      describe "when given a software as source" do
        let(:description) do
          proc do
            source(:git, from_dependency: "zoo")
          end
        end

        describe "before resolving version" do
          it "mentions the version is not ready yet" do
            expect(subject_with_description.explain).to match(/will be determined/)
          end

          it "includes the dependency name in the message" do
            expect(subject_with_description.explain).to match(/zoo/)
          end
        end

        describe "after resolving version" do
          before do
            expect(BuildVersion).to receive(:new).with("/etc/zoo").and_return(zoo_version)
            subject_with_description.resolve(zoo_software)
          end

          it "creates the version with path from source with semver" do
            expect(subject_with_description.explain).to eq("Build Version: 5.5.5")
          end
        end
      end

      describe "when not given a software as source" do
        let(:description) do
          proc { source(:git) }
        end

        it "creates the version with default path as semver" do
          expect(BuildVersion).to receive(:new).with(no_args).and_return(zoo_version)
          expect(subject_with_description.build_version).to eq("5.5.5")
        end
      end

      describe "when given an output format" do
        let(:description) do
          proc do
            source(:git)
            output_format(:custom)
          end
        end

        it "outputs the version with given function" do
          expect(BuildVersion).to receive(:new).with(no_args).and_return(zoo_version)
          expect(subject_with_description.build_version).to eq("7.7.7")
        end
      end
    end

    describe "when given a :version source" do
      describe "when given a software as source" do
        let(:description) do
          proc do
            source(:version, from_dependency: "zoo")
          end
        end

        it "creates the version with version from source" do
          subject_with_description.resolve(zoo_software)
          expect(subject_with_description.build_version).to eq("6.6.6")
        end
      end

      describe "when not given a software as source" do
        let(:description) do
          proc do
            source(:version)
          end
        end

        it "fails" do
          expect { subject_with_description.build_version }.to raise_error(RuntimeError)
        end
      end
    end

    describe "when given an unknown source" do
      let(:description) do
        proc do
          source(:park)
        end
      end

      it "fails" do
        expect { subject_with_description.build_version }.to raise_error(RuntimeError)
      end
    end
  end
end
