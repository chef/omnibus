require 'omnibus/software'

require 'spec_helper'

describe Omnibus::Software do

  let(:project) do
    double(Omnibus::Project, install_path: 'monkeys', overrides: {})
  end

  let(:software_name) { 'erchef' }
  let(:software_file) { software_path(software_name) }

  let(:software) do
    Omnibus::Software.load(software_file, project)
  end

  before do
    allow_any_instance_of(Omnibus::Software).to receive(:render_tasks)
  end

  describe '#whitelist_file' do
    it 'appends to the whitelist_files array' do
      expect(software.whitelist_files.size).to eq(0)
      software.whitelist_file(/foo\/bar/)
      expect(software.whitelist_files.size).to eq(1)
    end

    it 'converts Strings to Regexp instances' do
      software.whitelist_file 'foo/bar'
      expect(software.whitelist_files.size).to eq(1)
      expect(software.whitelist_files.first).to be_kind_of(Regexp)
    end
  end

  context 'testing repo-level version overrides' do
    let(:software_name) { 'zlib' }
    let(:default_version) { '1.2.6' }
    let(:expected_version) { '1.2.6' }
    let(:expected_override_version) { nil }
    let(:expected_md5) { '618e944d7c7cd6521551e30b32322f4a' }
    let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.6/zlib-1.2.6.tar.gz' }

    shared_examples_for 'a software definition' do
      it 'should have the same name' do
        expect(software.name).to eq(software_name)
      end

      it 'should have the same version' do
        expect(software.version).to eq(expected_version)
      end

      it 'should have the right default_version' do
        expect(software.default_version).to eq(default_version)
      end

      it 'should have nil for an override_version' do
        expect(software.override_version).to eq(expected_override_version)
      end

      it 'should have the md5 of the default version' do
        expect(software.source[:md5]).to eq(expected_md5)
      end

      it 'should have the url of the default version' do
        expect(software.source[:url]).to eq(expected_url)
      end
    end

    context 'without overrides' do
      it_behaves_like 'a software definition'
    end

    context 'with overrides for different software' do
      let(:overrides) { { 'chaos_monkey' => '1.2.8' } }
      let(:software) { Omnibus::Software.load(software_file, project, overrides) }

      it_behaves_like 'a software definition'
    end

    context 'with overrides for this software' do
      let(:expected_version) { '1.2.8' }
      let(:expected_override_version) { '1.2.8' }
      let(:overrides) { { software_name => expected_override_version } }
      let(:software) { Omnibus::Software.load(software_file, project, overrides) }
      let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
      let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

      it_behaves_like 'a software definition'
    end

    context 'with an overide in the project' do
      let(:project) do
        double(Omnibus::Project, install_path: 'monkeys', overrides: { zlib: { version: '1.2.8' } })
      end
      let(:expected_version) { '1.2.8' }
      let(:expected_override_version) { '1.2.8' }
      let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
      let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

      it_behaves_like 'a software definition'
    end

  end
end
