require 'spec_helper'

module Omnibus
  describe Digestable do
    let(:path) { '/path/to/file' }
    let(:io)   { StringIO.new }

    subject { Class.new { include Digestable }.new }

    describe '#digest' do
      it 'reads the IO in chunks' do
        expect(File).to receive(:open).with(path).and_yield(io)
        expect(subject.digest(path)).to eq('d41d8cd98f00b204e9800998ecf8427e')
      end
    end
  end
end
