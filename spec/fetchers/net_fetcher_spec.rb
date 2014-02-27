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
      env_vars = %w(HTTP_PROXY HTTP_PROXY_USER HTTP_PROXY_PASS http_proxy http_proxy_user http_proxy_pass)
      @orig_env = env_vars.reduce({}) do |h, var|
        h[var] = ENV.delete(var)
        h
      end
    end

    after(:each) do
      # restore ENV hash
      @orig_env.each { |var, val| ENV[var] = val }
    end

    describe 'get_env handles upper and lower case env vars' do
      it 'lower via upper' do
        ENV['lower'] = 'abc'
        expect(@net_fetcher.get_env('LOWER')).to eq('abc')
        expect(@net_fetcher.get_env('lower')).to eq('abc')
      end

      it 'upper via lower' do
        ENV['UPPER'] = 'abc'
        expect(@net_fetcher.get_env('upper')).to eq('abc')
        expect(@net_fetcher.get_env('UPPER')).to eq('abc')
      end
    end

    it 'should return nil when no proxy is set in env' do
      expect(@net_fetcher.http_proxy).to be_nil
    end

    it 'should return a URI object when HTTP_PROXY is set' do
      ENV['HTTP_PROXY'] = 'http://my.proxy'
      expect(@net_fetcher.http_proxy).to eq(URI.parse('http://my.proxy'))
    end

    it 'sets user and pass from env when set' do
      ENV['HTTP_PROXY'] = 'my.proxy'
      ENV['HTTP_PROXY_USER'] = 'alex'
      ENV['HTTP_PROXY_PASS'] = 'sesame'
      expect(@net_fetcher.http_proxy).to eq(URI.parse('http://alex:sesame@my.proxy'))
    end

    it 'uses user and pass in URL before those in env' do
      ENV['HTTP_PROXY'] = 'sally:peanut@my.proxy'
      ENV['HTTP_PROXY_USER'] = 'alex'
      ENV['HTTP_PROXY_PASS'] = 'sesame'
      expect(@net_fetcher.http_proxy).to eq(URI.parse('http://sally:peanut@my.proxy'))
    end

    it "proxies if host doesn't match exclude list" do
      ENV['NO_PROXY'] = 'google.com,www.buz.org'
      a_url = URI.parse('http://should.proxy.com/123')
      expect(@net_fetcher.excluded_from_proxy?(a_url.host)).to be_false

      b_url = URI.parse('http://buz.org/123')
      expect(@net_fetcher.excluded_from_proxy?(b_url.host)).to be_false
    end

    it 'does not proxy if host matches exclude list' do
      ENV['NO_PROXY'] = 'google.com,www.buz.org'
      a_url = URI.parse('http://google.com/hello')
      expect(@net_fetcher.excluded_from_proxy?(a_url.host)).to be_true

      b_url = URI.parse('http://www.buz.org/123')
      expect(@net_fetcher.excluded_from_proxy?(b_url.host)).to be_true
    end
  end
end
