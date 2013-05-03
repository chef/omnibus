#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

  let(:path) { "build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-11.4.0-1.el5.x86_64.rpm" }

  let(:content) { StringIO.new("this is the package content\n") }

  let(:md5) { "d41d8cd98f00b204e9800998ecf8427e" }

  let(:sha256) { "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }

  let(:platforms) { [ [ "el", "5", "x86_64" ], [ "sles","11.2","x86_64" ] ] }

  let(:artifact) { Omnibus::Artifact.new(path, platforms, { :version => "11.4.0-1" }) }

  it "has the path to the package" do
    artifact.path.should == path
  end

  it "has a list of platforms the package supports" do
    artifact.platforms.should == platforms
  end

  it "generates a MD5 of an artifact" do
    File.should_receive(:open).with(path).and_return(content)
    artifact.md5.should == md5
  end

  it "generates a SHA256 of an artifact" do
    File.should_receive(:open).with(path).and_return(content)
    artifact.sha256.should == sha256
  end

  it "generates 'flat' metadata" do
    File.should_receive(:open).twice.with(path).and_return(content)
    flat_metadata = artifact.flat_metadata
    flat_metadata["platform"].should == "el"
    flat_metadata["platform_version"].should == "5"
    flat_metadata["arch"].should == "x86_64"
    flat_metadata["version"].should == "11.4.0-1"
    flat_metadata["basename"].should == "demoproject-11.4.0-1.el5.x86_64.rpm"
    flat_metadata["md5"].should == md5
    flat_metadata["sha256"].should == sha256
  end

  it "adds the package to a release manifest" do
    expected = {
      "el" => {
        "5" => { "x86_64" => { "11.4.0-1" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm" } }
      },
      "sles" => {
        "11.2" => { "x86_64" => { "11.4.0-1" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm" } }
      }
    }

    manifest = artifact.add_to_release_manifest!({})
    manifest.should == expected
  end

  it "adds the package to a v2 release manifest" do
    File.should_receive(:open).with(path).twice.and_return(content)
    expected = {
      "el" => {
        "5" => { "x86_64" => { "11.4.0-1" => {
          "relpath" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm",
          "md5" => md5,
          "sha256" => sha256
            }
          }
        }
      },
      "sles" => {
        "11.2" => { "x86_64" => { "11.4.0-1" => {
          "relpath" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm",
          "md5" => md5,
          "sha256" => sha256
            }
          }
        }
      }
    }
    v2_manifest = artifact.add_to_v2_release_manifest!({})
    v2_manifest.should == expected
  end

end

