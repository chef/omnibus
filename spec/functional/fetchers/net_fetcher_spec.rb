require 'spec_helper'

module Omnibus
  describe NetFetcher do
    include_examples 'a software'

    let(:source_url) { 'http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz' }
    let(:source_md5) { '00b516f4704d4a7cb50a1d97e6e8e15b' }
    let(:source) do
      { url: source_url, md5: source_md5 }
    end

    let(:downloaded_file) { subject.send(:downloaded_file) }
    let(:extracted) { File.join(source_dir, 'bzip2-1.0.6') }

    subject { described_class.new(software) }

    describe '#fetch_required?' do
      context 'when the file is not downloaded' do
        it 'return true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context 'when the file is downloaded' do
        before { subject.fetch }

        context 'when the checksum is different' do
          it 'return true' do
            allow(subject).to receive(:checksum).and_return('abcd1234')
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context 'when the checksum is the same' do
          it 'return false' do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      it 'includes the source md5' do
        expect(subject.version_guid).to eq("md5:#{source_md5}")
      end
    end

    describe '#clean' do
      before { subject.fetch }

      context 'when the project directory exists' do
        before do
          create_file("#{project_dir}/file_a")
        end

        it 'extracts the asset' do
          subject.clean
          expect(extracted).to_not be_a_file
        end

        it 'returns true' do
          expect(subject.clean).to be_truthy
        end
      end

      context 'when the project directory does not exist' do
        before do
          remove_directory(project_dir)
        end

        it 'returns false' do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#fetch' do
      it 'downloads the file' do
        subject.fetch
        expect(downloaded_file).to be_a_file
      end

      context 'when the checksum is invalid' do
        let(:source_md5) { 'bad01234checksum' }

        it 'raises an exception' do
          expect { subject.fetch }.to raise_error(ChecksumMismatch)
        end
      end

      it 'extracts the file' do
        subject.fetch
        expect(extracted).to be_a_directory
      end
    end

    describe '#version_for_cache' do
      before do
        create_file("#{project_dir}/file_a")
        create_file("#{project_dir}/file_b")
        create_file("#{project_dir}/.file_c")
      end

      it 'includes the download_url and checksum' do
        expect(subject.version_for_cache).to eq("download_url:#{source_url}|md5:#{source_md5}")
      end
    end
  end
end
