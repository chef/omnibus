require 'spec_helper'

module Omnibus
  # Used in the tests
  class FakePublisher; end

  describe Publisher do
    it { should be_a_kind_of(Logging) }

    describe '.publish' do
      let(:publisher) { double(described_class) }

      before { allow(described_class).to receive(:new).and_return(publisher) }

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

      before do
        allow(FileSyncer).to receive(:glob)
          .with(pattern)
          .and_return(glob)
      end

      it 'returns an array' do
        expect(subject.packages).to be_an(Array)
      end

      it 'returns an array of Package objects' do
        expect(subject.packages.first).to be_a(Package)
      end

      context 'a platform mappings matrix is provided' do
        let(:options) do
          {
            platform_mappings: {
              'ubuntu-12.04' => [
                'ubuntu-12.04',
                'ubuntu-14.04',
              ],
            },
          }
        end

        let(:package) do
          Package.new('/path/to/files/chef.deb')
        end

        let(:metadata) do
          Metadata.new(package,
            name: 'chef',
            friendly_name: 'Chef',
            homepage: 'https://www.getchef.com',
            version: '11.0.6',
            iteration: 1,
            basename: 'chef.deb',
            platform: 'ubuntu',
            platform_version: '12.04',
            arch: 'x86_64',
            sha1: 'SHA1',
            md5: 'ABCDEF123456',
          )
        end

        before do
          allow(package).to receive(:metadata).and_return(metadata)
          allow(FileSyncer).to receive_message_chain(:glob, :map).and_return([package])
        end

        it 'creates a package for each publish platform' do
          expect(subject.packages.size).to eq(2)
          expect(
            subject.packages.map do |p|
              p.metadata[:platform_version]
            end
          ).to include('12.04', '14.04')
        end

        context 'the build platform does not exist' do
          let(:options) do
            {
              platform_mappings: {
                'ubuntu-10.04' => [
                  'ubuntu-12.04',
                  'ubuntu-14.04',
                ],
              },
            }
          end

          it 'raises an error' do
            expect { subject.packages }.to raise_error(InvalidBuildPlatform)
          end
        end
      end
    end

    describe '#publish' do
      it 'is an abstract method' do
        expect { subject.publish }.to raise_error(NotImplementedError)
      end
    end
  end
end
