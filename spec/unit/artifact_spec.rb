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

require 'omnibus/artifact'
require 'spec_helper'

describe Omnibus::Artifact do

  let(:path) { 'build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-11.4.0-1.el5.x86_64.rpm' }

  let(:content) { StringIO.new("this is the package content\n") }

  let(:md5) { 'd41d8cd98f00b204e9800998ecf8427e' }

  let(:sha256) { 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }

  let(:platforms) { [%w(el 5 x86_64), ['sles', '11.2', 'x86_64']] }

  let(:artifact) { Omnibus::Artifact.new(path, platforms,  version: '11.4.0-1') }

  it 'has the path to the package' do
    expect(artifact.path).to eq(path)
  end

  it 'has a list of platforms the package supports' do
    expect(artifact.platforms).to eq(platforms)
  end

  it 'generates a MD5 of an artifact' do
    expect(File).to receive(:open).with(path).and_return(content)
    expect(artifact.md5).to eq(md5)
  end

  it 'generates a SHA256 of an artifact' do
    expect(File).to receive(:open).with(path).and_return(content)
    expect(artifact.sha256).to eq(sha256)
  end

  it "generates 'flat' metadata" do
    expect(File).to receive(:open).twice.with(path).and_return(content)
    flat_metadata = artifact.flat_metadata
    expect(flat_metadata['platform']).to eq('el')
    expect(flat_metadata['platform_version']).to eq('5')
    expect(flat_metadata['arch']).to eq('x86_64')
    expect(flat_metadata['version']).to eq('11.4.0-1')
    expect(flat_metadata['basename']).to eq('demoproject-11.4.0-1.el5.x86_64.rpm')
    expect(flat_metadata['md5']).to eq(md5)
    expect(flat_metadata['sha256']).to eq(sha256)
  end

  it 'adds the package to a release manifest' do
    expected = {
      'el' => {
        '5' => { 'x86_64' => { '11.4.0-1' => '/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm' } },
      },
      'sles' => {
        '11.2' => { 'x86_64' => { '11.4.0-1' => '/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm' } },
      },
    }

    manifest = artifact.add_to_release_manifest!({})
    expect(manifest).to eq(expected)
  end

  it 'adds the package to a v2 release manifest' do
    expect(File).to receive(:open).with(path).twice.and_return(content)
    expected = {
      'el' => {
        '5' => {
          'x86_64' => {
            '11.4.0-1' => {
              'relpath' => '/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm',
              'md5' => md5,
              'sha256' => sha256,
            },
          },
        },
      },
      'sles' => {
        '11.2' => {
          'x86_64' => {
            '11.4.0-1' => {
              'relpath' => '/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm',
              'md5' => md5,
              'sha256' => sha256,
            },
          },
        },
      },
    }
    v2_manifest = artifact.add_to_v2_release_manifest!({})
    expect(v2_manifest).to eq(expected)
  end

end
