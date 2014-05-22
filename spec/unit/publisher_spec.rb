require 'spec_helper'

module Omnibus
  # Used in the tests
  class FakePublisher; end

  describe Publisher do
    it { should be_a_kind_of(Logging) }

    describe '.for' do
      context 'when given a string' do
        it 'returns the correct publisher' do
          expect(described_class.for('fake')).to be(FakePublisher)
        end
      end

      context 'when given a symbol' do
        it 'returns the correct publisher' do
          expect(described_class.for(:fake)).to be(FakePublisher)
        end
      end

      context 'when given an invalid backend' do
        it 'raises an exception' do
          expect { described_class.for(:hamlet) }.to raise_error(UnknownPublisher)
        end
      end
    end

    describe '.publish' do
      let(:publisher) { double(described_class) }

      before { described_class.stub(:new).and_return(publisher) }

      it 'creates a new instance of the class' do
        expect(described_class).to receive(:new).once
        expect(publisher).to receive(:publish).once
        described_class.publish('/path/to/*.deb')
      end
    end

    let(:pattern) { '/path/to/files/*.deb' }
    let(:options) { { some_option: true } }

    subject { described_class.new(pattern, options) }

    describe '#packages' do
      let(:a) { '/path/to/files/a.deb' }
      let(:b) { '/path/to/files/b.deb' }
      let(:glob) { [a, b] }

      before { Dir.stub(:glob).with(pattern).and_return(glob) }

      it 'returns an array' do
        expect(subject.packages).to be_an(Array)
      end

      it 'returns an array of Package objects' do
        expect(subject.packages.first).to be_a(Package)
      end
    end

    describe '#publish' do
      it 'is an abstract method' do
        expect { subject.publish }.to raise_error(AbstractMethod)
      end
    end
  end
end
