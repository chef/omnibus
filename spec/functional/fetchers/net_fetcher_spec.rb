require "spec_helper"

module Omnibus
  module RSpec
    module OhaiHelpers
      # Turn off the mandatory Ohai helper.
      def stub_ohai(options = {}, &block)
      end
    end
  end

  describe NetFetcher do
    include_examples "a software", "zlib"

    let(:source_url) { "http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz" }
    let(:source_md5) { "44d667c142d7cda120332623eab69f40" }
    let(:source_sha1) { "a4d316c404ff54ca545ea71a27af7dbc29817088" }
    let(:source_sha256) { "36658cb768a54c1d4dec43c3116c27ed893e88b02ecfcb44f2166f9c0b7f2a0d" }
    let(:source_sha512) { "ece209d4c7ec0cb58ede791444dc754e0d10811cbbdebe3df61c0fd9f9f9867c1c3ccd5f1827f847c005e24eef34fb5bf87b5d3f894d75da04f1797538290e4a" }

    let(:source) do
      { url: source_url, md5: source_md5 }
    end

    let(:downloaded_file) { subject.send(:downloaded_file) }
    let(:extracted) { File.join(source_dir, "zlib-1.2.8") }

    let(:fetch!) { capture_stdout { subject.fetch } }

    let(:manifest_entry) do
      double(ManifestEntry,
             name: "software",
             locked_version: "1.2.8",
             described_version: "1.2.8",
             locked_source: source)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do
      context "when the file is not downloaded" do
        it "return true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the file is downloaded" do
        before { fetch! }

        context "when the checksum is different" do
          it "return true" do
            allow(subject).to receive(:checksum).and_return("abcd1234")
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context "when the checksum is the same" do
          it "return false" do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      context "source with md5" do
        it "includes the md5 digest" do
          expect(subject.version_guid).to eq("md5:#{source_md5}")
        end
      end

      context "source with sha1" do
        let(:source) do
          { url: source_url, sha1: source_sha1 }
        end

        it "includes the sha1 digest" do
          expect(subject.version_guid).to eq("sha1:#{source_sha1}")
        end
      end

      context "source with sha256" do
        let(:source) do
          { url: source_url, sha256: source_sha256 }
        end

        it "includes the sha256 digest" do
          expect(subject.version_guid).to eq("sha256:#{source_sha256}")
        end
      end

      context "source with sha512" do
        let(:source) do
          { url: source_url, sha512: source_sha512 }
        end

        it "includes the sha512 digest" do
          expect(subject.version_guid).to eq("sha512:#{source_sha512}")
        end
      end
    end

    describe '#clean' do
      before { fetch! }

      context "when the project directory exists" do
        before do
          create_file("#{project_dir}/file_a")
        end

        it "extracts the asset" do
          subject.clean
          expect(extracted).to_not be_a_file
        end

        it "returns true" do
          expect(subject.clean).to be_truthy
        end
      end

      context "when the project directory does not exist" do
        before do
          remove_directory(project_dir)
        end

        it "returns false" do
          expect(subject.clean).to be(false)
        end
      end

      context "when the source has read-only files" do
        let(:source_url) { "http://dl.bintray.com/oneclick/OpenKnapsack/x86/openssl-1.0.0q-x86-windows.tar.lzma" }
        let(:source_md5) { "577dbe528415c6f178a9431fd0554df4" }

        it "extracts the asset without crashing" do
          subject.clean
          expect(extracted).to_not be_a_file
          subject.clean
          expect(extracted).to_not be_a_file
        end
      end

      context "when the source has broken symlinks" do
        let(:source_url) { "http://www.openssl.org/source/openssl-1.0.1q.tar.gz" }
        let(:source_md5) { "54538d0cdcb912f9bc2b36268388205e" }

        let(:source) do
          { url: source_url, md5: source_md5, extract: :lax_tar }
        end

        it "extracts the asset without crashing" do
          subject.clean
          expect(extracted).to_not be_a_file
          subject.clean
          expect(extracted).to_not be_a_file
        end
      end
    end

    describe '#fetch' do
      context "source with md5" do
        it "downloads the file" do
          fetch!
          expect(downloaded_file).to be_a_file
        end

        context "when the checksum is invalid" do
          let(:source_md5) { "bad01234checksum" }

          it "raises an exception" do
            expect { fetch! }.to raise_error(ChecksumMismatch)
          end
        end
      end

      context "source with no checksum" do
        let(:source) do
          { url: source_url }
        end

        it "raises an exception" do
          expect { fetch! }.to raise_error(ChecksumMissing)
        end
      end

      context "source with sha1" do
        let(:source) do
          { url: source_url, sha1: source_sha1 }
        end

        it "downloads the file" do
          fetch!
          expect(downloaded_file).to be_a_file
        end

        context "when the checksum is invalid" do
          let(:source_sha1) { "bad01234checksum" }

          it "raises an exception" do
            expect { fetch! }.to raise_error(ChecksumMismatch)
          end
        end
      end

      context "source with sha256" do
        let(:source) do
          { url: source_url, sha256: source_sha256 }
        end

        it "downloads the file" do
          fetch!
          expect(downloaded_file).to be_a_file
        end

        context "when the checksum is invalid" do
          let(:source_sha256) { "bad01234checksum" }

          it "raises an exception" do
            expect { fetch! }.to raise_error(ChecksumMismatch)
          end
        end
      end

      context "source with sha512" do
        let(:source) do
          { url: source_url, sha512: source_sha512 }
        end

        it "downloads the file" do
          fetch!
          expect(downloaded_file).to be_a_file
        end

        context "when the checksum is invalid" do
          let(:source_sha512) { "bad01234checksum" }

          it "raises an exception" do
            expect { fetch! }.to raise_error(ChecksumMismatch)
          end
        end
      end

      it "when the download times out" do
        # Mock the Timeout::Error for this particular test only
        WebMock.disable_net_connect!
        stub_request(:get, "http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz").to_timeout
        output = capture_logging do
          expect { subject.send(:download) }.to raise_error(Timeout::Error)
        end

        expect(output).to include("Retrying failed download")
        expect(output).to include("Download failed")
        retry_count = output.scan("Retrying failed download").count
        expect(retry_count).to eq(Omnibus::Config.fetcher_retries)
      end

      context "when the file is less than 10240 bytes" do
        let(:source_url) { "https://downloads.chef.io/packages-chef-io-public.key" }
        let(:source_md5) { "369efc3a19b9118cdf51c7e87a34f266" }

        it "downloads the file" do
          fetch!
          expect(downloaded_file).to be_a_file
        end
      end
    end

    describe '#version_for_cache' do
      before do
        create_file("#{project_dir}/file_a")
        create_file("#{project_dir}/file_b")
        create_file("#{project_dir}/.file_c")
      end

      context "source with md5" do
        it "includes the download_url and checksum" do
          expect(subject.version_for_cache).to eq("download_url:#{source_url}|md5:#{source_md5}")
        end
      end

      context "source with sha1" do
        let(:source) do
          { url: source_url, sha1: source_sha1 }
        end

        it "includes the download_url and checksum" do
          expect(subject.version_for_cache).to eq("download_url:#{source_url}|sha1:#{source_sha1}")
        end
      end

      context "source with sha256" do
        let(:source) do
          { url: source_url, sha256: source_sha256 }
        end

        it "includes the download_url and checksum" do
          expect(subject.version_for_cache).to eq("download_url:#{source_url}|sha256:#{source_sha256}")
        end
      end

      context "source with sha512" do
        let(:source) do
          { url: source_url, sha512: source_sha512 }
        end

        it "includes the download_url and checksum" do
          expect(subject.version_for_cache).to eq("download_url:#{source_url}|sha512:#{source_sha512}")
        end
      end
    end
  end
end
