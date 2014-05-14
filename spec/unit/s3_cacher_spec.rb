require 'spec_helper'

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
