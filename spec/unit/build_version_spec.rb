#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'omnibus/build_version'
require 'spec_helper'

describe Omnibus::BuildVersion do

  let(:git_describe) { '11.0.0-alpha1-207-g694b062' }
  let(:valid_semver_regex) { /^\d+\.\d+\.\d+(\-[\dA-Za-z\-\.]+)?(\+[\dA-Za-z\-\.]+)?$/ }
  let(:valid_git_describe_regex) { /^\d+\.\d+\.\d+(\-[A-Za-z0-9\-\.]+)?(\-\d+\-g[0-9a-f]+)?$/ }

  subject(:build_version) { Omnibus::BuildVersion.new }

  before :each do
    ENV['BUILD_ID'] = nil
    ENV['OMNIBUS_APPEND_TIMESTAMP'] = nil
    Omnibus::BuildVersion.any_instance.stub(:shellout)
      .and_return(double('ouput', stdout: git_describe, exitstatus: 0))
  end

  describe 'git describe parsing' do

    # we prefer our git tags to be SemVer compliant

    # release version
    context '11.0.1' do
      let(:git_describe) { '11.0.1' }
      its(:version_tag) { should == '11.0.1' }
      its(:prerelease_tag) { should be_nil }
      its(:git_sha_tag) { should be_nil }
      its(:commits_since_tag) { should == 0 }
      its(:development_version?) { should be_true }
      its(:prerelease_version?) { should be_false }
    end

    # SemVer compliant prerelease version
    context '11.0.0-alpha.2' do
      let(:git_describe) { '11.0.0-alpha.2' }
      its(:version_tag) { should == '11.0.0' }
      its(:prerelease_tag) { should == 'alpha.2' }
      its(:git_sha_tag) { should be_nil }
      its(:commits_since_tag) { should == 0 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end

    # full git describe string
    context '11.0.0-alpha.3-59-gf55b180' do
      let(:git_describe) { '11.0.0-alpha.3-59-gf55b180' }
      its(:version_tag) { should == '11.0.0' }
      its(:prerelease_tag) { should == 'alpha.3' }
      its(:git_sha_tag) { should == 'f55b180' }
      its(:commits_since_tag) { should == 59 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end

    # Degenerate git tag formats

    # RubyGems compliant git tag
    context '10.16.0.rc.0' do
      let(:git_describe) { '10.16.0.rc.0' }
      its(:version_tag) { should == '10.16.0' }
      its(:prerelease_tag) { should == 'rc.0' }
      its(:git_sha_tag) { should be_nil }
      its(:commits_since_tag) { should == 0 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end

    # dash seperated prerelease
    context '11.0.0-alpha-2' do
      let(:git_describe) { '11.0.0-alpha-2' }
      its(:version_tag) { should == '11.0.0' }
      its(:prerelease_tag) { should == 'alpha-2' }
      its(:git_sha_tag) { should be_nil }
      its(:commits_since_tag) { should == 0 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end

    # dash seperated prerelease full git describe string
    context '11.0.0-alpha-2-59-gf55b180' do
      let(:git_describe) { '11.0.0-alpha-2-59-gf55b180' }
      its(:version_tag) { should == '11.0.0' }
      its(:prerelease_tag) { should == 'alpha-2' }
      its(:git_sha_tag) { should == 'f55b180' }
      its(:commits_since_tag) { should == 59 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end

    # WTF git tag
    context '11.0.0-alpha2' do
      let(:git_describe) { '11.0.0-alpha2' }
      its(:version_tag) { should == '11.0.0' }
      its(:prerelease_tag) { should == 'alpha2' }
      its(:git_sha_tag) { should be_nil }
      its(:commits_since_tag) { should == 0 }
      its(:development_version?) { should be_false }
      its(:prerelease_version?) { should be_true }
    end
  end

  describe 'semver output' do
    let(:today_string) { Time.now.utc.strftime('%Y%m%d') }

    it 'generates a valid semver version' do
      expect(build_version.semver).to match(valid_semver_regex)
    end

    it "generates a version matching format 'MAJOR.MINOR.PATCH-PRERELEASE+TIMESTAMP.git.COMMITS_SINCE.GIT_SHA'" do
      expect(build_version.semver).to match(/11.0.0-alpha1\+#{today_string}[0-9]+.git.207.694b062/)
    end

    it "uses ENV['BUILD_ID'] to generate timestamp if set" do
      ENV['BUILD_ID'] = '2012-12-25_16-41-40'
      expect(build_version.semver).to eq('11.0.0-alpha1+20121225164140.git.207.694b062')
    end

    it "fails on invalid ENV['BUILD_ID'] values" do
      ENV['BUILD_ID'] = 'AAAA'
      expect { build_version.semver }.to raise_error(ArgumentError)
    end

    context 'prerelease version with dashes' do
      let(:git_describe) { '11.0.0-alpha-3-207-g694b062' }

      it 'converts all dashes to dots' do
        expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
      end
    end

    context 'exact version' do
      let(:git_describe) { '11.0.0-alpha2' }

      it 'appends a timestamp with no git info' do
        expect(build_version.semver).to match(/11.0.0-alpha2\+#{today_string}[0-9]+/)
      end
    end

    describe 'appending a timestamp' do
      let(:git_describe) { '11.0.0-alpha-3-207-g694b062' }

      it 'appends a timestamp by default' do
        expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
      end

      describe "ENV['OMNIBUS_APPEND_TIMESTAMP'] is set" do
        ['true', 't', 'yes', 'y', 1].each do |truthy|
          context "to #{truthy}" do
            before { ENV['OMNIBUS_APPEND_TIMESTAMP'] = truthy.to_s }
            it 'appends a timestamp' do
              expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
            end
          end
        end

        ['false', 'f', 'no', 'n', 0].each do |falsey|
          context "to #{falsey}" do
            before { ENV['OMNIBUS_APPEND_TIMESTAMP'] = falsey.to_s }
            it 'does not append a timestamp' do
              expect(build_version.semver).to match(/11.0.0-alpha.3\+git.207.694b062/)
            end
          end
        end
      end

      describe 'Omnibus::Config.append_timestamp is set' do
        context 'is true' do
          before { Omnibus::Config.append_timestamp(true) }
          it 'appends a timestamp' do
            expect(build_version.semver).to match(/11.0.0-alpha.3\+#{today_string}[0-9]+.git.207.694b062/)
          end
        end

        context 'is false' do
          before { Omnibus::Config.append_timestamp(false) }
          it 'does not append a timestamp' do
            expect(build_version.semver).to match(/11.0.0-alpha.3\+git.207.694b062/)
          end
        end
      end

      describe 'both are set' do
        before do
          ENV['OMNIBUS_APPEND_TIMESTAMP'] = 'false'
          Omnibus::Config.append_timestamp(true)
        end
        it "prefers the value from ENV['OMNIBUS_APPEND_TIMESTAMP']" do
          expect(build_version.semver).to match(/11.0.0-alpha.3\+git.207.694b062/)
        end
      end
    end
  end

  describe 'git describe output' do
    it 'generates a valid git describe version' do
      expect(build_version.git_describe).to match(valid_git_describe_regex)
    end

    it "generates a version matching format 'MAJOR.MINOR.PATCH-PRELEASE.COMMITS_SINCE-gGIT_SHA'" do
      expect(build_version.git_describe).to eq(git_describe)
    end
  end

  describe 'deprecated full output' do
    it 'generates a valid git describe version' do
      expect(Omnibus::BuildVersion.full).to match(valid_git_describe_regex)
    end

    it 'outputs a deprecation message' do
      expect(Omnibus::BuildVersion).to receive(:puts).with(/is deprecated/)
      Omnibus::BuildVersion.full
    end
  end

  describe '`git describe` command failure' do
    before do
      stderr = <<-STDERR
fatal: No tags can describe '809ea1afcce67e1148c1bf0822d40a7ef12c380e'.
Try --always, or create some tags.
      STDERR
      build_version.stub(:shellout)
        .and_return(double('ouput', stderr: stderr, exitstatus: 128))
    end
    it 'sets the version to 0.0.0' do
      expect(build_version.git_describe).to eq('0.0.0')
    end
  end

  describe '#initialize `path` parameter' do
    let(:path) { '/some/fake/path' }
    subject(:build_version) { Omnibus::BuildVersion.new(path) }

    it 'runs `git describe` at an alternate path' do
      expect(build_version).to receive(:shellout)
        .with('git describe', live_stream: nil, cwd: path)
        .and_return(double('ouput', stdout: git_describe, exitstatus: 0))
      build_version.git_describe
    end
  end
end
