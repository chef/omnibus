#
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
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

require 'spec_helper'
require 'omnibus/s3_cacher'

describe Omnibus::S3Cache do

  describe '#tarball_software' do
    subject(:tarball_software) { described_class.new.tarball_software }

    let(:source_a) { double(source: { url: 'a' }) }
    let(:source_b) { double(source: { url: 'b' }) }
    let(:source_c) { double(source: {}) }
    let(:projects) do
      [
        double(library: [source_a, source_c]),
        double(library: [source_c, source_b]),
      ]
    end
    let(:software_with_urls) { [source_a, source_b] }

    before do
      Omnibus.stub(config: double(s3_bucket: 'test', s3_access_key: 'test', s3_secret_key: 'test'))
      Omnibus.stub(projects: projects)
    end

    it 'lists all software with urls' do
      expect(tarball_software).to eq(software_with_urls)
    end
  end
end
