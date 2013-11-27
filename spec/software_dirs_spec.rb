require 'omnibus'
require 'spec_helper'

describe Omnibus do

  describe '#software_dirs' do

    before :each do
      # This is probably really silly, but it works
      Omnibus.class_eval { @software_dirs = nil }
    end

    context 'omnibus_software_root not nil' do
      before :each do
        Omnibus.stub(:omnibus_software_root) { './data' }
      end

      it 'will include list of software from omnibus-software gem' do
        Omnibus.software_dirs.length.should eq 2
      end
    end

    context 'omnibus_software_root nil' do
      before :each do
        Omnibus.stub(:omnibus_software_root) { nil }
      end

      it 'will not include list of software from omnibus-software gem' do
        Omnibus.software_dirs.length.should eq 1
      end
    end
  end

end
