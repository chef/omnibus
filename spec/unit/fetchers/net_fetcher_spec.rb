require 'spec_helper'

module Omnibus
  describe NetFetcher do
    let(:project_dir) { '/tmp/project' }
    let(:build_dir) { '/tmp/build' }
    let(:source) do
      { url: 'https://get.example.com/file.tar.gz', md5: 'abcd1234' }
    end

    let(:manifest_entry) do
      double(Omnibus::ManifestEntry,
             name: 'file',
             locked_version: "1.2.3",
             described_version: '1.2.3',
             locked_source: source)
    end

    let(:cache_dir) { '/cache' }

    before do
      Config.cache_dir(cache_dir)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do
      context 'when file is not downloaded' do
        before { allow(File).to receive(:exist?).and_return(false) }

        it 'returns true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context 'when the file is downloaded' do
        before { allow(File).to receive(:exist?).and_return(true) }

        context 'when the shasums differ' do
          before do
            allow(subject).to receive(:digest).and_return('abcd1234')
            allow(subject).to receive(:checksum).and_return('efgh5678')
          end

          it 'returns true' do
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context 'when the shasums are the same' do
          before do
            allow(subject).to receive(:digest).and_return('abcd1234')
            allow(subject).to receive(:checksum).and_return('abcd1234')
          end

          it 'returns true' do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      context 'source with md5' do
        it 'returns the shasum' do
          expect(subject.version_guid).to eq('md5:abcd1234')
        end
      end

      context 'source with sha1' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha1: 'abcd1234' }
        end

        it 'returns the shasum' do
          expect(subject.version_guid).to eq('sha1:abcd1234')
        end
      end

      context 'source with sha256' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha256: 'abcd1234' }
        end

        it 'returns the shasum' do
          expect(subject.version_guid).to eq('sha256:abcd1234')
        end
      end

      context 'source with sha512' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha512: 'abcd1234' }
        end

        it 'returns the shasum' do
          expect(subject.version_guid).to eq('sha512:abcd1234')
        end
      end
    end

    describe '#clean' do
      before do
        allow(FileUtils).to receive(:rm_rf)
        allow(subject).to receive(:extract)
      end

      context 'when the project directory exists' do
        before { allow(File).to receive(:exist?).and_return(true) }

        it 'extracts the archive' do
          expect(subject).to receive(:extract)
          subject.clean
        end

        it 'returns true' do
          expect(subject.clean).to be_truthy
        end

        it 'removes the project directory' do
          expect(FileUtils).to receive(:rm_rf).with(project_dir)
          subject.clean
        end
      end

      context 'when the project directory does not exist' do
        before { allow(File).to receive(:exist?).and_return(false) }

        it 'extracts the archive' do
          expect(subject).to receive(:extract)
          subject.clean
        end

        it 'returns false' do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#version_for_cache' do
      context 'source with md5' do
        it 'returns the download URL and md5' do
          expect(subject.version_for_cache).to eq('download_url:https://get.example.com/file.tar.gz|md5:abcd1234')
        end
      end

      context 'source with sha1' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha1: 'abcd1234' }
        end

        it 'returns the download URL and sha1' do
          expect(subject.version_for_cache).to eq('download_url:https://get.example.com/file.tar.gz|sha1:abcd1234')
        end
      end

      context 'source with sha256' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha256: 'abcd1234' }
        end

        it 'returns the download URL and sha256' do
          expect(subject.version_for_cache).to eq('download_url:https://get.example.com/file.tar.gz|sha256:abcd1234')
        end
      end

      context 'source with sha512' do
        let(:source) do
          { url: 'https://get.example.com/file.tar.gz', sha512: 'abcd1234' }
        end

        it 'returns the download URL and sha1' do
          expect(subject.version_for_cache).to eq('download_url:https://get.example.com/file.tar.gz|sha512:abcd1234')
        end
      end
    end

    describe "downloading the file" do

      let(:expected_open_opts) do
        {
          "Accept-Encoding" => "identity",
          :read_timeout => 60,
          :content_length_proc => an_instance_of(Proc),
          :progress_proc => an_instance_of(Proc)
        }
      end

      let(:tempfile_path) { "/tmp/intermediate_path/tempfile_path.random_garbage.tmp" }

      let(:fetched_file) { instance_double("File", path: tempfile_path) }

      let(:destination_path) { "/cache/file.tar.gz" }

      let(:progress_bar_output) { StringIO.new }

      let(:reported_content_length) { 100 }

      let(:cumulative_downloaded_length) { 100 }

      def capturing_stdout
        old_stdout, $stdout = $stdout, progress_bar_output
        yield
      ensure
        $stdout = old_stdout
      end


      before do
        expect(subject).to receive(:open).with(source[:url], expected_open_opts) do |_url, open_uri_opts|
          open_uri_opts[:content_length_proc].call(reported_content_length)
          open_uri_opts[:progress_proc].call(cumulative_downloaded_length)

          fetched_file
        end
        expect(FileUtils).to receive(:cp).with(tempfile_path, destination_path)
        expect(fetched_file).to receive(:close)
      end

      it "downloads the thing" do
        capturing_stdout do
          expect { subject.send(:download) }.to_not raise_error
        end
      end

      # In Ci we somewhat frequently see:
      #   ProgressBar::InvalidProgressError: You can't set the item's current value to be greater than the total.
      #
      # My hunch is that this is caused by some floating point shenanigans
      # where we sum a bunch of floating point numbers and they add up to some
      # small fraction greater than the actual total. Since we're gonna verify
      # the checksum of what we downloaded later, we don't want to hear about
      # this error.
      context "when cumulative downloaded amount exceeds reported content length" do

        let(:reported_content_length) { 100 }

        let(:cumulative_downloaded_length) { 100.1 }

        it "downloads the thing" do
          capturing_stdout do
            expect { subject.send(:download) }.to_not raise_error
          end
        end

      end

    end

    shared_examples 'an extractor' do |extension, command|
      context "when the file is a .#{extension}" do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: 'file',
                 locked_version: "1.2.3",
                 described_version: '1.2.3',
                 locked_source: { url: "https://get.example.com/file.#{extension}", md5: 'abcd1234' })
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        it 'is the right command' do
          expect(subject.send(:extract_command)).to eq(command)
        end
      end
    end

    describe '#extract' do
      before do
        described_class.send(:public, :extract)
      end

      context 'when the downloaded file is a folder' do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: 'file',
                 locked_version: "1.2.3",
                 described_version: '1.2.3',
                 locked_source: { url: "https://get.example.com/folder", md5: 'abcd1234' })
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        before do
          allow(FileUtils).to receive(:cp_r)
          allow(File).to receive(:directory?).and_return(true)
        end

        it 'copies the entire directory to project_dir' do
          allow(subject).to receive(:extract_command)
          expect(FileUtils).to receive(:cp_r).with("#{cache_dir}/folder", project_dir)
          subject.extract
        end
      end

      context 'when the downloaded file is a regular file' do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: 'file',
                 locked_version: "1.2.3",
                 described_version: '1.2.3',
                 locked_source: { url: "https://get.example.com/file", md5: 'abcd1234' })
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        before do
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:cp)
          allow(File).to receive(:directory?).and_return(false)
        end

        it 'copies the file into the project_dir' do
          allow(subject).to receive(:extract_command)
          expect(FileUtils).to receive(:cp).with("#{cache_dir}/file", "#{project_dir}/")
          subject.extract
        end
      end
    end

    describe '#extract_command' do
      before { Config.source_dir('/tmp/out') }

      context 'on Windows' do
        before do
          Config.cache_dir('C:')
          stub_ohai(platform: 'windows', version: '2012')
        end

        it_behaves_like 'an extractor', '7z',      '7z.exe x C:\\file.7z -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'zip',     '7z.exe x C:\\file.zip -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'tar',     'tar xf C:\\file.tar -C/tmp/out'
        it_behaves_like 'an extractor', 'tgz',     'tar zxf C:\\file.tgz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.gz',  'tar zxf C:\\file.tar.gz -C/tmp/out'
        it_behaves_like 'an extractor', 'bz2',     'tar jxf C:\\file.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.bz2', 'tar jxf C:\\file.tar.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'txz',     'tar Jxf C:\\file.txz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.xz',  'tar Jxf C:\\file.tar.xz -C/tmp/out'
      end

      context 'on Linux' do
        before do
          Config.cache_dir('/')
          stub_ohai(platform: 'ubuntu', version: '12.04')
          stub_const('File::ALT_SEPARATOR', nil)
        end

        it_behaves_like 'an extractor', '7z',      '7z x /file.7z -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'zip',     'unzip /file.zip -d /tmp/out'
        it_behaves_like 'an extractor', 'tar',     'tar xf /file.tar -C/tmp/out'
        it_behaves_like 'an extractor', 'tgz',     'tar zxf /file.tgz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.gz',  'tar zxf /file.tar.gz -C/tmp/out'
        it_behaves_like 'an extractor', 'bz2',     'tar jxf /file.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.bz2', 'tar jxf /file.tar.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'txz',     'tar Jxf /file.txz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.xz',  'tar Jxf /file.tar.xz -C/tmp/out'
      end

      context 'when gtar is present' do
        before do
          Config.cache_dir('/')

          stub_ohai(platform: 'ubuntu', version: '12.04')
          stub_const('File::ALT_SEPARATOR', nil)

          allow(Omnibus).to receive(:which)
            .with('gtar')
            .and_return('/path/to/gtar')
        end

        it_behaves_like 'an extractor', '7z',      '7z x /file.7z -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'zip',     'unzip /file.zip -d /tmp/out'
        it_behaves_like 'an extractor', 'tar',     'gtar xf /file.tar -C/tmp/out'
        it_behaves_like 'an extractor', 'tgz',     'gtar zxf /file.tgz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.gz',  'gtar zxf /file.tar.gz -C/tmp/out'
        it_behaves_like 'an extractor', 'bz2',     'gtar jxf /file.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.bz2', 'gtar jxf /file.tar.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'txz',     'gtar Jxf /file.txz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.xz',  'gtar Jxf /file.tar.xz -C/tmp/out'
      end
    end
  end
end
