require "spec_helper"

module Omnibus
  describe NetFetcher do
    let(:root_prefix) { "" }
    let(:project_dir) { "#{root_prefix}/tmp/project" }
    let(:build_dir) { "#{root_prefix}/tmp/build" }
    let(:source) do
      { url: "https://get.example.com/file.tar.gz", md5: "abcd1234" }
    end

    let(:manifest_entry) do
      double(Omnibus::ManifestEntry,
             name: "file",
             locked_version: "1.2.3",
             described_version: "1.2.3",
             locked_source: source)
    end

    let(:cache_dir) { "/cache" }

    before do
      Config.cache_dir(cache_dir)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do
      context "when file is not downloaded" do
        before { allow(File).to receive(:exist?).and_return(false) }

        it "returns true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the file is downloaded" do
        before { allow(File).to receive(:exist?).and_return(true) }

        context "when the shasums differ" do
          before do
            allow(subject).to receive(:digest).and_return("abcd1234")
            allow(subject).to receive(:checksum).and_return("efgh5678")
          end

          it "returns true" do
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context "when the shasums are the same" do
          before do
            allow(subject).to receive(:digest).and_return("abcd1234")
            allow(subject).to receive(:checksum).and_return("abcd1234")
          end

          it "returns true" do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      context "source with md5" do
        it "returns the shasum" do
          expect(subject.version_guid).to eq("md5:abcd1234")
        end
      end

      context "source with sha1" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha1: "abcd1234" }
        end

        it "returns the shasum" do
          expect(subject.version_guid).to eq("sha1:abcd1234")
        end
      end

      context "source with sha256" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha256: "abcd1234" }
        end

        it "returns the shasum" do
          expect(subject.version_guid).to eq("sha256:abcd1234")
        end
      end

      context "source with sha512" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha512: "abcd1234" }
        end

        it "returns the shasum" do
          expect(subject.version_guid).to eq("sha512:abcd1234")
        end
      end
    end

    describe '#clean' do
      before do
        allow(FileUtils).to receive(:rm_rf)
        allow(subject).to receive(:deploy)
        allow(subject).to receive(:create_required_directories)
      end

      context "when the project directory exists" do
        before { allow(File).to receive(:exist?).and_return(true) }

        it "deploys the archive" do
          expect(subject).to receive(:deploy)
          subject.clean
        end

        it "returns true" do
          expect(subject.clean).to be_truthy
        end

        it "removes the project directory" do
          expect(FileUtils).to receive(:rm_rf).with(project_dir)
          subject.clean
        end
      end

      context "when the project directory does not exist" do
        before { allow(File).to receive(:exist?).and_return(false) }

        it "deploys the archive" do
          expect(subject).to receive(:deploy)
          subject.clean
        end

        it "returns false" do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#version_for_cache' do
      context "source with md5" do
        it "returns the download URL and md5" do
          expect(subject.version_for_cache).to eq("download_url:https://get.example.com/file.tar.gz|md5:abcd1234")
        end
      end

      context "source with sha1" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha1: "abcd1234" }
        end

        it "returns the download URL and sha1" do
          expect(subject.version_for_cache).to eq("download_url:https://get.example.com/file.tar.gz|sha1:abcd1234")
        end
      end

      context "source with sha256" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha256: "abcd1234" }
        end

        it "returns the download URL and sha256" do
          expect(subject.version_for_cache).to eq("download_url:https://get.example.com/file.tar.gz|sha256:abcd1234")
        end
      end

      context "source with sha512" do
        let(:source) do
          { url: "https://get.example.com/file.tar.gz", sha512: "abcd1234" }
        end

        it "returns the download URL and sha1" do
          expect(subject.version_for_cache).to eq("download_url:https://get.example.com/file.tar.gz|sha512:abcd1234")
        end
      end
    end

    describe "downloading the file" do

      let(:expected_open_opts) do
        {
          "Accept-Encoding" => "identity",
          :read_timeout => 60,
          :content_length_proc => an_instance_of(Proc),
          :progress_proc => an_instance_of(Proc),
        }
      end

      let(:tempfile_path) { "/tmp/intermediate_path/tempfile_path.random_garbage.tmp" }

      let(:fetched_file) { instance_double("TempFile", path: tempfile_path) }

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
        expect(fetched_file).to receive(:close)
        expect(FileUtils).to receive(:cp).with(tempfile_path, destination_path)
        expect(fetched_file).to receive(:unlink)
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

    shared_examples "an extractor" do |extension, source_options, commands|
      context "when the file is a .#{extension}" do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: "file",
                 locked_version: "1.2.3",
                 described_version: "1.2.3",
                 locked_source: { url: "https://get.example.com/file.#{extension}", md5: "abcd1234" }.merge(source_options)
                )
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        it "shells out with the right commands" do
          commands.each do |command|
            if command.is_a?(String)
              expect(subject).to receive(:shellout!).with(command)
            else
              expect(subject).to receive(:shellout!).with(*command)
            end
          end
          subject.send(:extract)
        end
      end
    end

    describe '#deploy' do
      before do
        described_class.send(:public, :deploy)
      end

      context "when the downloaded file is a folder" do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: "file",
                 locked_version: "1.2.3",
                 described_version: "1.2.3",
                 locked_source: { url: "https://get.example.com/folder", md5: "abcd1234" })
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        before do
          allow(File).to receive(:directory?).and_return(true)
        end

        it "copies the entire directory to project_dir" do
          expect(FileUtils).to receive(:cp_r).with("#{cache_dir}/folder/.", project_dir)
          subject.deploy
        end
      end

      context "when the downloaded file is a regular file" do
        let(:manifest_entry) do
          double(Omnibus::ManifestEntry,
                 name: "file",
                 locked_version: "1.2.3",
                 described_version: "1.2.3",
                 locked_source: { url: "https://get.example.com/file", md5: "abcd1234" })
        end

        subject { described_class.new(manifest_entry, project_dir, build_dir) }

        before do
          allow(File).to receive(:directory?).and_return(false)
        end

        it "copies the file into the project_dir" do
          expect(FileUtils).to receive(:cp).with("#{cache_dir}/file", "#{project_dir}")
          subject.deploy
        end
      end
    end

    describe '#extract' do

      context "on Windows" do
        let(:root_prefix) { "C:" }

        before do
          Config.cache_dir("C:/")
          stub_ohai(platform: "windows", version: "2012")
          allow(Dir).to receive(:mktmpdir).and_yield("C:/tmp_dir")
        end

        context "when no extract overrides are present" do
          it_behaves_like "an extractor", "7z", {},
            ['7z.exe x C:\\file.7z -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "zip", {},
            ['7z.exe x C:\\file.zip -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar", {},
            [['tar xf C:\\file.tar -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "tgz", {},
            [['tar zxf C:\\file.tgz -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "tar.gz", {},
            [['tar zxf C:\\file.tar.gz -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "tar.bz2", {},
            [['tar jxf C:\\file.tar.bz2 -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "txz", {},
            [['tar Jxf C:\\file.txz -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "tar.xz", {},
            [['tar Jxf C:\\file.tar.xz -CC:\\tmp\\project', { returns: [0] }]]
          it_behaves_like "an extractor", "tar.lzma", {},
            [['tar --lzma -xf C:\\file.tar.lzma -CC:\\tmp\\project', { returns: [0] }]]
        end

        context "when seven_zip extract strategy is chosen" do
          it_behaves_like "an extractor", "7z", { extract: :seven_zip },
            ['7z.exe x C:\\file.7z -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "zip", { extract: :seven_zip },
            ['7z.exe x C:\\file.zip -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar", { extract: :seven_zip },
            ['7z.exe x C:\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tgz", { extract: :seven_zip },
            ['7z.exe x C:\\file.tgz -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar.gz", { extract: :seven_zip },
            ['7z.exe x C:\\file.tar.gz -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar.bz2", { extract: :seven_zip },
            ['7z.exe x C:\\file.tar.bz2 -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "txz", { extract: :seven_zip },
            ['7z.exe x C:\\file.txz -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar.xz", { extract: :seven_zip },
            ['7z.exe x C:\\file.tar.xz -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar.lzma", { extract: :seven_zip },
            ['7z.exe x C:\\file.tar.lzma -oC:\\tmp_dir -r -y',
             '7z.exe x C:\\tmp_dir\\file.tar -oC:\\tmp\\project -r -y']
        end

        context "when lax_tar extract strategy is chosen" do
          it_behaves_like "an extractor", "7z", { extract: :lax_tar },
            ['7z.exe x C:\\file.7z -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "zip", { extract: :lax_tar },
            ['7z.exe x C:\\file.zip -oC:\\tmp\\project -r -y']
          it_behaves_like "an extractor", "tar", { extract: :lax_tar },
            [['tar xf C:\\file.tar -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "tgz", { extract: :lax_tar },
            [['tar zxf C:\\file.tgz -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "tar.gz", { extract: :lax_tar },
            [['tar zxf C:\\file.tar.gz -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "tar.bz2", { extract: :lax_tar },
            [['tar jxf C:\\file.tar.bz2 -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "txz", { extract: :lax_tar },
            [['tar Jxf C:\\file.txz -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "tar.xz", { extract: :lax_tar },
            [['tar Jxf C:\\file.tar.xz -CC:\\tmp\\project', { returns: [0, 1] }]]
          it_behaves_like "an extractor", "tar.lzma", { extract: :lax_tar },
            [['tar --lzma -xf C:\\file.tar.lzma -CC:\\tmp\\project', { returns: [0, 1] }]]
        end
      end

      context "on Linux" do
        before do
          Config.cache_dir("/")
          stub_ohai(platform: "ubuntu", version: "12.04")
          stub_const("File::ALT_SEPARATOR", nil)
        end

        context "when gtar is not present" do
          it_behaves_like "an extractor", "7z", {},
            ["7z x /file.7z -o/tmp/project -r -y"]
          it_behaves_like "an extractor", "zip", {},
            ["unzip /file.zip -d /tmp/project"]
          it_behaves_like "an extractor", "tar", {},
            ["tar xf /file.tar -C/tmp/project"]
          it_behaves_like "an extractor", "tgz", {},
            ["tar zxf /file.tgz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.gz", {},
            ["tar zxf /file.tar.gz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.bz2", {},
            ["tar jxf /file.tar.bz2 -C/tmp/project"]
          it_behaves_like "an extractor", "txz", {},
            ["tar Jxf /file.txz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.xz", {},
            ["tar Jxf /file.tar.xz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.lzma", {},
            ["tar --lzma -xf /file.tar.lzma -C/tmp/project"]
        end

        context "when gtar is present" do
          before do
            Config.cache_dir("/")

            stub_ohai(platform: "ubuntu", version: "12.04")
            stub_const("File::ALT_SEPARATOR", nil)

            allow(Omnibus).to receive(:which)
            .with("gtar")
            .and_return("/path/to/gtar")
          end

          it_behaves_like "an extractor", "7z", {},
            ["7z x /file.7z -o/tmp/project -r -y"]
          it_behaves_like "an extractor", "zip", {},
            ["unzip /file.zip -d /tmp/project"]
          it_behaves_like "an extractor", "tar", {},
            ["gtar xf /file.tar -C/tmp/project"]
          it_behaves_like "an extractor", "tgz", {},
            ["gtar zxf /file.tgz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.gz", {},
            ["gtar zxf /file.tar.gz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.bz2", {},
            ["gtar jxf /file.tar.bz2 -C/tmp/project"]
          it_behaves_like "an extractor", "txz", {},
            ["gtar Jxf /file.txz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.xz", {},
            ["gtar Jxf /file.tar.xz -C/tmp/project"]
          it_behaves_like "an extractor", "tar.lzma", {},
            ["gtar --lzma -xf /file.tar.lzma -C/tmp/project"]
        end

      end
    end
  end
end
