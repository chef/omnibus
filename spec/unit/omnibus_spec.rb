require 'omnibus'
require 'spec_helper'

describe Omnibus do
  before do
    allow(File).to receive(:directory?).and_return(true)

    allow(Gem::Specification).to receive(:find_all_by_name)
      .with('omnibus-software')
      .and_return([double(gem_dir: '/gem/omnibus-software')])

    allow(Gem::Specification).to receive(:find_all_by_name)
      .with('custom-omnibus-software')
      .and_return([double(gem_dir: '/gem/custom-omnibus-software')])

    Omnibus::Config.project_root('/foo/bar')
    Omnibus::Config.local_software_dirs(['/local', '/other'])
    Omnibus::Config.software_gems(['omnibus-software', 'custom-omnibus-software'])
  end

  describe '#software_dirs' do
    let(:software_dirs) { Omnibus.software_dirs }

    it 'includes project_root' do
      expect(software_dirs).to include('/foo/bar/config/software')
    end

    it 'includes local_software_dirs dirs' do
      expect(software_dirs).to include('/local/config/software')
      expect(software_dirs).to include('/other/config/software')
    end

    it 'includes software_gems dirs' do
      expect(software_dirs).to include('/gem/omnibus-software/config/software')
      expect(software_dirs).to include('/gem/custom-omnibus-software/config/software')
    end

    it 'has the correct precedence order' do
      expect(software_dirs).to eq([
        '/foo/bar/config/software',
        '/local/config/software',
        '/other/config/software',
        '/gem/omnibus-software/config/software',
        '/gem/custom-omnibus-software/config/software',
      ])
    end
  end

  describe '#software_map' do
    let(:software_map) { Omnibus.send(:software_map) }

    it 'returns a hash' do
      expect(software_map).to be_a(Hash)
    end
  end
end
