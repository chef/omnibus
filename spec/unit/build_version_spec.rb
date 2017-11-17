require "spec_helper"

module Omnibus
  describe BuildVersion do
    let(:git_describe) { "11.0.0-alpha1-207-g694b062" }
    let(:valid_semver_regex) { /^\d+\.\d+\.\d+(\-[\dA-Za-z\-\.]+)?(\+[\dA-Za-z\-\.]+)?$/ }
    let(:valid_git_describe_regex) { /^\d+\.\d+\.\d+(\-[A-Za-z0-9\-\.]+)?(\-\d+\-g[0-9a-f]+)?$/ }

    subject(:build_version) { described_class.new }

    before do
      Config.append_timestamp(true)
      allow_any_instance_of(described_class).to receive(:shellout)
        .and_return(double("ouput", stdout: git_describe, exitstatus: 0))
    end

    describe "git describe parsing" do

      # we prefer our git tags to be SemVer compliant

      # release version
      context "11.0.1" do
        let(:git_describe) { "11.0.1" }
        its(:version_tag) { should == "11.0.1" }
        its(:prerelease_tag) { should be_nil }
        its(:git_sha_tag) { should be_nil }
        its(:commits_since_tag) { should == 0 }
        its(:prerelease_version?) { should be(false) }
      end

      # SemVer compliant prerelease version
      context "11.0.0-alpha.2" do
        let(:git_describe) { "11.0.0-alpha.2" }
        its(:version_tag) { should == "11.0.0" }
        its(:prerelease_tag) { should == "alpha.2" }
        its(:git_sha_tag) { should be_nil }
        its(:commits_since_tag) { should == 0 }
        its(:prerelease_version?) { should be_truthy }
      end

      # full git describe string
      context "11.0.0-alpha.3-59-gf55b180" do
        let(:git_describe) { "11.0.0-alpha.3-59-gf55b180" }
        its(:version_tag) { should == "11.0.0" }
        its(:prerelease_tag) { should == "alpha.3" }
        its(:git_sha_tag) { should == "f55b180" }
        its(:commits_since_tag) { should == 59 }
        its(:prerelease_version?) { should be_truthy }
      end

      # Degenerate git tag formats

      # RubyGems compliant git tag
      context "10.16.0.rc.0" do
        let(:git_describe) { "10.16.0.rc.0" }
        its(:version_tag) { should == "10.16.0" }
        its(:prerelease_tag) { should == "rc.0" }
        its(:git_sha_tag) { should be_nil }
        its(:commits_since_tag) { should == 0 }
        its(:prerelease_version?) { should be_truthy }
      end

      # dash seperated prerelease
      context "11.0.0-alpha-2" do
        let(:git_describe) { "11.0.0-alpha-2" }
        its(:version_tag) { should == "11.0.0" }
        its(:prerelease_tag) { should == "alpha-2" }
        its(:git_sha_tag) { should be_nil }
        its(:commits_since_tag) { should == 0 }
        its(:prerelease_version?) { should be_truthy }
      end

      # dash seperated prerelease full git describe string
      context "11.0.0-alpha-2-59-gf55b180" do
        let(:git_describe) { "11.0.0-alpha-2-59-gf55b180" }
        its(:version_tag) { should == "11.0.0" }
        its(:prerelease_tag) { should == "alpha-2" }
        its(:git_sha_tag) { should == "f55b180" }
        its(:commits_since_tag) { should == 59 }
        its(:prerelease_version?) { should be_truthy }
      end

      # WTF git tag
      context "11.0.0-alpha2" do
        let(:git_describe) { "11.0.0-alpha2" }
        its(:version_tag) { should == "11.0.0" }
        its(:prerelease_tag) { should == "alpha2" }
        its(:git_sha_tag) { should be_nil }
        its(:commits_since_tag) { should == 0 }
        its(:prerelease_version?) { should be_truthy }
      end

      # v-prefixed tag
      context "v1.2.3-beta2" do
        let(:git_describe) { "v1.2.3-beta2" }
        its(:version_tag) { should == "1.2.3" }
        its(:prerelease_tag) { should == "beta2" }
        its(:git_sha_tag) { should be(nil) }
        its(:commits_since_tag) { should eq(0) }
        its(:prerelease_version?) { should be(true) }
      end
    end

    describe "semver output" do
      let(:today_string) { Time.now.utc.strftime("%Y%m%d") }

      it "generates a valid semver version" do
        expect(build_version.semver).to match(valid_semver_regex)
      end

      it "generates a version matching format 'MAJOR.MINOR.PATCH-PRERELEASE+TIMESTAMP.git.COMMITS_SINCE.GIT_SHA'" do
        expect(build_version.semver).to match(/11.0.0-alpha1\+#{today_string}[0-9]+.git.207.694b062/)
      end

      it "uses ENV['BUILD_TIMESTAMP'] to generate timestamp if set" do
        stub_env("BUILD_TIMESTAMP", "2012-12-25_16-41-40")
        expect(build_version.semver).to eq("11.0.0-alpha1+20121225164140.git.207.694b062")
      end

      it "fails on invalid ENV['BUILD_TIMESTAMP'] values" do
        stub_env("BUILD_TIMESTAMP", "AAAA")
        expect { build_version.semver }.to raise_error(ArgumentError)
      end

      it "uses ENV['BUILD_ID'] to generate timestamp if set and BUILD_TIMESTAMP is not set" do
        stub_env("BUILD_ID", "2012-12-25_16-41-40")
        expect(build_version.semver).to eq("11.0.0-alpha1+20121225164140.git.207.694b062")
      end

      it "fails on invalid ENV['BUILD_ID'] values" do
        stub_env("BUILD_ID", "AAAA")
        expect { build_version.semver }.to raise_error(ArgumentError)
      end

      context "prerelease version with dashes" do
        let(:git_describe) { "11.0.0-alpha-3-207-g694b062" }

        it "converts all dashes to dots" do
          expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
        end
      end

      context "exact version" do
        let(:git_describe) { "11.0.0-alpha2" }

        it "appends a timestamp with no git info" do
          expect(build_version.semver).to match(/11.0.0-alpha2\+#{today_string}[0-9]+/)
        end
      end

      describe "appending a timestamp" do
        let(:git_describe) { "11.0.0-alpha-3-207-g694b062" }
        context "by default" do
          it "appends a timestamp" do
            expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
          end
        end

        context "when Config.append_timestamp is true" do
          it "appends a timestamp" do
            expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
          end
        end

        context "when Config.append_timestamp is false" do
          before { Config.append_timestamp(false) }
          it "does not append a timestamp" do
            expect(build_version.semver).to match(/11.0.0-alpha.3\+git.207.694b062/)
          end
        end
      end
    end

    describe "git describe output" do
      it "generates a valid git describe version" do
        expect(build_version.git_describe).to match(valid_git_describe_regex)
      end

      it "generates a version matching format 'MAJOR.MINOR.PATCH-PRELEASE.COMMITS_SINCE-gGIT_SHA'" do
        expect(build_version.git_describe).to eq(git_describe)
      end
    end

    describe "`git describe` command failure" do
      before do
        stderr = <<-STDERR
  fatal: No tags can describe '809ea1afcce67e1148c1bf0822d40a7ef12c380e'.
  Try --always, or create some tags.
        STDERR
        allow(build_version).to receive(:shellout)
          .and_return(double("ouput", stderr: stderr, exitstatus: 128))
      end
      it "sets the version to 0.0.0" do
        expect(build_version.git_describe).to eq("0.0.0")
      end
    end

    describe "#initialize `path` parameter" do
      let(:path) { "/some/fake/path" }
      subject(:build_version) { BuildVersion.new(path) }

      it "runs `git describe` at an alternate path" do
        expect(build_version).to receive(:shellout)
          .with("git describe --tags", cwd: path)
          .and_return(double("ouput", stdout: git_describe, exitstatus: 0))
        build_version.git_describe
      end
    end
  end
end
