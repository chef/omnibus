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

  describe '#project_path' do
    before do
      allow(Omnibus).to receive(:project_map)
        .and_return('chef' => '/projects/chef')
    end

    it 'accepts a string' do
      expect(subject.project_path('chef')).to eq('/projects/chef')
    end

    it 'accepts a symbol' do
      expect(subject.project_path(:chef)).to eq('/projects/chef')
    end

    it 'returns nil when the project does not exist' do
      expect(subject.project_path('bacon')).to be nil
    end
  end

  describe '#software_path' do
    before do
      allow(Omnibus).to receive(:software_map)
        .and_return('chef' => '/software/chef')
    end

    it 'accepts a string' do
      expect(subject.software_path('chef')).to eq('/software/chef')
    end

    it 'accepts a symbol' do
      expect(subject.software_path(:chef)).to eq('/software/chef')
    end

    it 'returns nil when the project does not exist' do
      expect(subject.software_path('bacon')).to be nil
    end
  end

  describe '#possible_paths_for' do
    it 'searches all paths' do
      expect(subject.possible_paths_for('file')).to eq(%w(
        /foo/bar/file
        /local/file
        /other/file
        /gem/omnibus-software/file
        /gem/custom-omnibus-software/file
      ))
    end
  end
end
