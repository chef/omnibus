require 'spec_helper'

describe Omnibus::NetFetcher do
  it 'should download and uncompress zip files' do
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
  it 'should download and uncompress .tar.xz files' do
    software_mock = double('software')
    software_mock.stub project_file: 'file.tar.xz',
                       name: 'file',
                       source: '/tmp/out',
                       checksum: 'abc123',
                       source_uri: 'http://example.com/file.tar.xz',
                       source_dir: '/tmp/out',
                       project_dir: '/tmp/project'
    net_fetcher = Omnibus::NetFetcher.new software_mock
    expect(net_fetcher.extract_cmd).to eq('xz -dc file.tar.xz | ( cd /tmp/out && tar -xf - )')
  end
  it 'should download and uncompress .txz files' do
    software_mock = double('software')
    software_mock.stub project_file: 'file.txz',
                       name: 'file',
                       source: '/tmp/out',
                       checksum: 'abc123',
                       source_uri: 'http://example.com/file.txz',
                       source_dir: '/tmp/out',
                       project_dir: '/tmp/project'
    net_fetcher = Omnibus::NetFetcher.new software_mock
    expect(net_fetcher.extract_cmd).to eq('xz -dc file.txz | ( cd /tmp/out && tar -xf - )')
  end

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
