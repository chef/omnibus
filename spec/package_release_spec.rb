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

require 'omnibus/package_release'
require 'spec_helper'

describe Omnibus::PackageRelease do
  let(:s3_key) { 's3key' }
  let(:s3_secret) { 'hey-bezos-store-my-stuff' }
  let(:s3_bucket) { 'myorg-omnibus-packages' }
  let(:pkg_path) { 'pkg/chef_11.4.0-183-g2c0040c-0.el6.x86_64.rpm' }
  let(:pkg_metadata_path) { "#{pkg_path}.metadata.json" }

  let(:config) do
    {
      release_s3_access_key: s3_key,
      release_s3_secret_key: s3_secret,
      release_s3_bucket: s3_bucket,
    }
  end
  subject(:package_release) do
    Omnibus::PackageRelease.new(pkg_path)
  end

  it 'has a package path' do
    expect(package_release.package_path).to eq(pkg_path)
  end

  it "defaults to `:private' access policy" do
    expect(package_release.access_policy).to eq(:private)
  end

  describe 'validating configuration' do

    before do
      Omnibus.stub(:config).and_return(config)
    end

    it 'validates that the s3 key is set' do
      config.delete(:release_s3_access_key)
      expect { package_release.validate_config! }.to raise_error(Omnibus::InvalidS3ReleaseConfiguration)
    end

    it 'validates that the s3 secret key is set' do
      config.delete(:release_s3_secret_key)
      expect { package_release.validate_config! }.to raise_error(Omnibus::InvalidS3ReleaseConfiguration)
    end

    it 'validates that the s3 bucket is set' do
      config.delete(:release_s3_bucket)
      expect { package_release.validate_config! }.to raise_error(Omnibus::InvalidS3ReleaseConfiguration)
    end

    it 'does not error on a valid configuration' do
      expect { package_release.validate_config! }.to_not raise_error
    end
  end

  describe 'validating package for upload' do
    it 'ensures that the package file exists' do
      expect { package_release.validate_package! }.to raise_error(Omnibus::NoPackageFile)
    end

    it 'ensures that there is a metadata file for the package' do
      expect(File).to receive(:exist?).with(pkg_path).and_return(true)
      expect(File).to receive(:exist?).with(pkg_metadata_path).and_return(false)
      expect { package_release.validate_package! }.to raise_error(Omnibus::NoPackageMetadataFile)
    end
  end

  context 'with a valid config and package' do

    let(:basename) { 'chef_11.4.0-183-g2c0040c-0.el6.x86_64.rpm' }
    let(:md5) { '016f2e0854c69901b3f0ad8f99ffdb75' }
    let(:platform_path) { 'el/6/x86_64' }
    let(:pkg_content) { 'expected package content' }

    let(:metadata_json) do
      <<-E
{
  "platform": "el",
  "platform_version": "6",
  "arch": "x86_64",
  "version": "11.4.0-183-g2c0040c",
  "basename": "#{basename}",
  "md5": "#{md5}",
  "sha256": "21191ab698d1663a5e738e470fad16a2c6efee05ed597002f2e846ec80ade38c"
}
      E
    end

    before do
      package_release.stub(:config).and_return(config)
      File.stub(:exist?).with(pkg_metadata_path).and_return(true)
      File.stub(:exist?).with(pkg_path).and_return(true)
      IO.stub(:read).with(pkg_metadata_path).and_return(metadata_json)
      IO.stub(:read).with(pkg_path).and_return(pkg_content)
    end

    it 'configures s3 with the given credentials' do
      expected_s3_config = {
        access_key: s3_key,
        secret_access_key: s3_secret,
        bucket: s3_bucket,
        adaper: :net_http,
      }
      expect(UberS3).to receive(:new).with(expected_s3_config)
      package_release.s3_client
    end

    it 'generates the relative path for the package s3 key' do
      expect(package_release.platform_path).to eq(platform_path)
    end

    it 'uploads the package and metadata' do
      expect(package_release.s3_client).to receive(:store).with(
        "#{platform_path}/#{basename}.metadata.json",
        metadata_json,
        access: :private,
      )
      expect(package_release.s3_client).to receive(:store).with(
        "#{platform_path}/#{basename}",
        pkg_content,
        access: :private,
        content_md5: md5,
      )
      package_release.release
    end

    context 'and a callback is given for after upload' do
      let(:upload_records) { [] }

      subject(:package_release) do
        Omnibus::PackageRelease.new(pkg_path) do |uploaded|
          upload_records << uploaded
        end
      end

      it 'fires the after_upload callback for each item uploaded' do
        expect(package_release.s3_client).to receive(:store).with(
          "#{platform_path}/#{basename}.metadata.json",
          metadata_json,
          access: :private,
        )
        expect(package_release.s3_client).to receive(:store).with(
          "#{platform_path}/#{basename}",
          pkg_content,
          access: :private,
          content_md5: md5,
        )
        package_release.release

        expect(upload_records).to eq [
          "#{platform_path}/#{basename}.metadata.json",
          "#{platform_path}/#{basename}",
        ]
      end
    end

    context 'and the package is public' do

      subject(:package_release) do
        Omnibus::PackageRelease.new(pkg_path, access: :public_read)
      end

      it 'uploads the package and metadata' do
        expect(package_release.s3_client).to receive(:store).with(
          "#{platform_path}/#{basename}.metadata.json",
          metadata_json,
          access: :public_read,
        )
        expect(package_release.s3_client).to receive(:store).with(
          "#{platform_path}/#{basename}",
          pkg_content,
          access: :public_read,
          content_md5: md5,
        )
        package_release.release
      end
    end

  end

end
