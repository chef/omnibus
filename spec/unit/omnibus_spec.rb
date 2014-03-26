require 'omnibus'
require 'spec_helper'

describe Omnibus do
  # evil class variables
  before :each do
    Omnibus.class_eval { @omnibus_software_root = nil }
    Omnibus.class_eval { @software_dirs = nil }
  end

  after :each do
    Omnibus.class_eval { @omnibus_software_root = nil }
    Omnibus.class_eval { @software_dirs = nil }
  end

  describe '::omnibus_software_root' do
    it 'reads the software_gem out of Omnibus::Config.software_gem' do
      spec_array = [double(Gem::Specification, gem_dir: '/data')]
      expect(Omnibus::Config).to receive(:software_gem)
        .and_return('my-omnibus-software-gem')
      expect(Gem::Specification).to receive(:find_all_by_name)
        .with('my-omnibus-software-gem')
        .and_return(spec_array)

      Omnibus.omnibus_software_root
    end

    it 'uses the omnibus-software gem as the default' do
      spec_array = [double(Gem::Specification, gem_dir: '/data')]
      expect(Gem::Specification).to receive(:find_all_by_name)
        .with('omnibus-software')
        .and_return(spec_array)

      Omnibus.omnibus_software_root
    end
  end

  describe '#software_dirs' do
    context 'omnibus_software_root not nil' do
      before do
        Omnibus.stub(:omnibus_software_root) { './data' }
      end

      it 'will include list of software from omnibus-software gem' do
        expect(Omnibus.software_dirs.length).to eq(2)
      end
    end

    context 'omnibus_software_root nil' do
      before do
        Omnibus.stub(:omnibus_software_root) { nil }
      end

      it 'will not include list of software from omnibus-software gem' do
        expect(Omnibus.software_dirs.length).to eq(1)
      end
    end
  end
end
