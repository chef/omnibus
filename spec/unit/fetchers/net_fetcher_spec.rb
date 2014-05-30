require 'spec_helper'
require 'ohai'

describe Omnibus::NetFetcher do
  context 'archive handling on Windows' do
    before do
      stub_ohai(platform: 'windows')
    end

    %w(7z zip).each do |ext|
      it "should download and uncompress #{ext} files with 7z.exe" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("7z.exe x file.#{ext} -o/tmp/out -r -y")
      end
    end

    %w(tgz tar.gz).each do |ext|
      it "should download and uncompress #{ext} files with tar zxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar zxf file.#{ext} -C/tmp/out")
      end
    end

    %w(bz2 tar.bz2).each do |ext|
      it "should download and uncompress #{ext} files with tar jxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar jxf file.#{ext} -C/tmp/out")
      end
    end

    %w(txz tar.xz).each do |ext|
      it "should download and uncompress #{ext} files with tar Jxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar Jxf file.#{ext} -C/tmp/out")
      end
    end

    %w(tar).each do |ext|
      it "should download and uncompress #{ext} files with tar xf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar xf file.#{ext} -C/tmp/out")
      end
    end
  end

  context 'archive handling on non-Windows' do
    before do
      stub_ohai(platform: 'linux')
    end

    %w(tgz tar.gz).each do |ext|
      it "should download and uncompress #{ext} files with tar zxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar zxf file.#{ext} -C/tmp/out")
      end
    end

    %w(bz2 tar.bz2).each do |ext|
      it "should download and uncompress #{ext} files with tar jxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar jxf file.#{ext} -C/tmp/out")
      end
    end

    %w(txz tar.xz).each do |ext|
      it "should download and uncompress #{ext} files with tar Jxf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar Jxf file.#{ext} -C/tmp/out")
      end
    end

    %w(tar).each do |ext|
      it "should download and uncompress #{ext} files with tar xf" do
        software_mock = double('software')
        software_mock.stub project_file: "file.#{ext}",
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: "http://example.com/file.#{ext}",
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        net_fetcher = Omnibus::NetFetcher.new software_mock
        expect(net_fetcher.extract_cmd).to eq("tar xf file.#{ext} -C/tmp/out")
      end
    end

    it 'should download and uncompress .7z files with 7z' do
      software_mock = double('software')
      software_mock.stub project_file: 'file.7z',
                         name: 'file',
                         source: '/tmp/out',
                         checksum: 'abc123',
                         source_uri: 'http://example.com/file.7z',
                         source_dir: '/tmp/out',
                         project_dir: '/tmp/project'
      net_fetcher = Omnibus::NetFetcher.new software_mock
      expect(net_fetcher.extract_cmd).to eq('7z x file.7z -o/tmp/out -r -y')
    end

    it 'should download and uncompress zip files with unzip' do
      software_mock = double('software')
      software_mock.stub project_file: 'file.zip',
                         name: 'file',
                         source: '/tmp/out',
                         checksum: 'abc123',
                         source_uri: 'http://example.com/file.zip',
                         source_dir: '/tmp/out',
                         project_dir: '/tmp/project'
      net_fetcher = Omnibus::NetFetcher.new software_mock
      expect(net_fetcher.extract_cmd).to eq('unzip file.zip -d /tmp/out')
    end
  end

  context 'URI handling' do
    describe 'http_proxy helper' do
      before(:each) do
        software_mock = double('software')
        software_mock.stub project_file: 'file.txz',
                           name: 'file',
                           source: '/tmp/out',
                           checksum: 'abc123',
                           source_uri: 'http://example.com/file.txz',
                           source_dir: '/tmp/out',
                           project_dir: '/tmp/project'
        @net_fetcher = Omnibus::NetFetcher.new(software_mock)
      end

      describe 'get_env handles upper and lower case env vars' do
        it 'lower via upper' do
          stub_env('lower', 'abc')
          expect(@net_fetcher.get_env('LOWER')).to eq('abc')
          expect(@net_fetcher.get_env('lower')).to eq('abc')
        end

        it 'upper via lower' do
          stub_env('UPPER', 'abc')
          expect(@net_fetcher.get_env('upper')).to eq('abc')
          expect(@net_fetcher.get_env('UPPER')).to eq('abc')
        end
      end

      it 'should return nil when no proxy is set in env' do
        expect(@net_fetcher.http_proxy).to be_nil
      end

      it 'should return a URI object when HTTP_PROXY is set' do
        stub_env('HTTP_PROXY', 'http://my.proxy')
        expect(@net_fetcher.http_proxy).to eq(URI.parse('http://my.proxy'))
      end

      it 'sets user and pass from env when set' do
        stub_env('HTTP_PROXY', 'my.proxy')
        stub_env('HTTP_PROXY_USER', 'alex')
        stub_env('HTTP_PROXY_PASS', 'sesame')
        expect(@net_fetcher.http_proxy).to eq(URI.parse('http://alex:sesame@my.proxy'))
      end

      it 'uses user and pass in URL before those in env' do
        stub_env('HTTP_PROXY', 'sally:peanut@my.proxy')
        stub_env('HTTP_PROXY_USER', 'alex')
        stub_env('HTTP_PROXY_PASS', 'sesame')
        expect(@net_fetcher.http_proxy).to eq(URI.parse('http://sally:peanut@my.proxy'))
      end

      it "proxies if host doesn't match exclude list" do
        stub_env('NO_PROXY', 'google.com,www.buz.org')
        a_url = URI.parse('http://should.proxy.com/123')
        expect(@net_fetcher.excluded_from_proxy?(a_url.host)).to be_falsey

        b_url = URI.parse('http://buz.org/123')
        expect(@net_fetcher.excluded_from_proxy?(b_url.host)).to be_falsey
      end

      it 'does not proxy if host matches exclude list' do
        stub_env('NO_PROXY', 'google.com,www.buz.org')
        a_url = URI.parse('http://google.com/hello')
        expect(@net_fetcher.excluded_from_proxy?(a_url.host)).to be_truthy

        b_url = URI.parse('http://www.buz.org/123')
        expect(@net_fetcher.excluded_from_proxy?(b_url.host)).to be_truthy
      end
    end
  end
end
