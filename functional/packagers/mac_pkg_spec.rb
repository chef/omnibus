#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

require 'stringio'
require 'omnibus/packagers/mac_pkg'
require 'spec_helper'

describe Omnibus::Packagers::MacPkg do

  let(:mac_pkg_identifier) { "test.pkg.functional-test-project" }

  let(:omnibus_root) { File.expand_path("../../fixtures/mac_pkg", __FILE__) }

  let(:scripts_path) { "#{omnibus_root}/package-scripts" }

  let(:files_path) { "#{omnibus_root}/files" }

  let(:package_dir) { Dir.pwd }

  let(:project) do
    double(Omnibus::Project,
           :name => "functional-test-project",
           :version => "23.4.2",
           :install_path => "/opt/functional-test-project",
           :package_scripts_path => scripts_path,
           :files_path => files_path,
           :package_dir => package_dir,
           :mac_pkg_identifier => mac_pkg_identifier)

  end


  let(:packager) do
    Omnibus::Packagers::MacPkg.new(project)
  end

  def create_app_dir
    FileUtils.mkdir("/opt/functional-test-project") unless File.directory?("/opt/functional-test-project")
    File.open("/opt/functional-test-project/itworks.txt", "w+") do |f|
      f.puts "hello world"
    end
  end

  # This will run the Omnibus::Packagers::MacPkg code without any stubs to
  # verify it works.  In order for this test to run correctly, you have to run
  # as root or manually create the /opt/functional-test-project directory.
  #
  # There is no verification that the package was correctly created, you have
  # to install it yourself to verify.
  it "builds a package" do
    create_app_dir
    packager.build
  end

end

