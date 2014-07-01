require 'spec_helper'

module Omnibus
  describe NetFetcher do
    let(:software_mock) do
      double(Software,
        project_file: 'file.tar.gz',
        name: 'file',
        source: '/tmp/out',
        checksum: 'abc123',
        source_uri: 'http://example.com/file.tar.gz',
        project_dir: '/tmp/project',
      )
    end

    before do
      Config.source_dir('/tmp/out')
    end

    shared_examples 'an extractor' do |extension, command|
      context "when the file is a .#{extension}" do
        before do
          software_mock.stub(
            project_file: "file.#{extension}",
            source_uri: "http://example.com/file.#{extension}",
          )
        end

        it 'downloads and decompresses the archive' do
          expect(subject.extract_cmd).to eq(command)
        end
      end
    end

    subject { described_class.new(software_mock) }

    describe '#extract_cmd' do
      context 'on Windows' do
        before { stub_ohai(platform: 'windows', version: '2012') }

        it_behaves_like 'an extractor', '7z',      '7z.exe x file.7z -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'zip',     '7z.exe x file.zip -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'tar',     'tar xf file.tar -C/tmp/out'
        it_behaves_like 'an extractor', 'tgz',     'tar zxf file.tgz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.gz',  'tar zxf file.tar.gz -C/tmp/out'
        it_behaves_like 'an extractor', 'bz2',     'tar jxf file.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.bz2', 'tar jxf file.tar.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'txz',     'tar Jxf file.txz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.xz',  'tar Jxf file.tar.xz -C/tmp/out'
      end

      context 'on Linux' do
        before { stub_ohai(platform: 'ubuntu', version: '12.04') }

        it_behaves_like 'an extractor', '7z',      '7z x file.7z -o/tmp/out -r -y'
        it_behaves_like 'an extractor', 'zip',     'unzip file.zip -d /tmp/out'
        it_behaves_like 'an extractor', 'tar',     'tar xf file.tar -C/tmp/out'
        it_behaves_like 'an extractor', 'tgz',     'tar zxf file.tgz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.gz',  'tar zxf file.tar.gz -C/tmp/out'
        it_behaves_like 'an extractor', 'bz2',     'tar jxf file.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.bz2', 'tar jxf file.tar.bz2 -C/tmp/out'
        it_behaves_like 'an extractor', 'txz',     'tar Jxf file.txz -C/tmp/out'
        it_behaves_like 'an extractor', 'tar.xz',  'tar Jxf file.tar.xz -C/tmp/out'
      end
    end

    describe '#get_env' do
      it 'handles upper via lower' do
        stub_env('lower', 'abc')
        expect(subject.get_env('LOWER')).to eq('abc')
        expect(subject.get_env('lower')).to eq('abc')
      end

      it 'handles lower via upper' do
        stub_env('UPPER', 'abc')
        expect(subject.get_env('upper')).to eq('abc')
        expect(subject.get_env('UPPER')).to eq('abc')
      end
    end

    describe '#http_proxy' do
      it 'returns nil when no proxy is set in env' do
        expect(subject.http_proxy).to be_nil
      end

      it 'returns a URI object when HTTP_PROXY is set' do
        stub_env('HTTP_PROXY', 'http://my.proxy')
        expect(subject.http_proxy).to eq(URI.parse('http://my.proxy'))
      end

      it 'sets user and pass from env when set' do
        stub_env('HTTP_PROXY', 'my.proxy')
        stub_env('HTTP_PROXY_USER', 'alex')
        stub_env('HTTP_PROXY_PASS', 'sesame')
        expect(subject.http_proxy).to eq(URI.parse('http://alex:sesame@my.proxy'))
      end

      it 'uses user and pass in URL before those in env' do
        stub_env('HTTP_PROXY', 'sally:peanut@my.proxy')
        stub_env('HTTP_PROXY_USER', 'alex')
        stub_env('HTTP_PROXY_PASS', 'sesame')
        expect(subject.http_proxy).to eq(URI.parse('http://sally:peanut@my.proxy'))
      end
    end

    describe '#excluded_from_proxy?' do
      it 'proxies if host does not match exclude list' do
        stub_env('NO_PROXY', 'google.com,www.buz.org')
        expect(subject.excluded_from_proxy?('should.proxy.com')).to be_falsey
        expect(subject.excluded_from_proxy?('www.buzz.org')).to be_falsey
      end

      it 'does not proxy if host matches exclude list' do
        stub_env('NO_PROXY', 'google.com,www.buz.org')
        expect(subject.excluded_from_proxy?('http://google.com')).to be_truthy
        expect(subject.excluded_from_proxy?('www.buz.org')).to be_truthy
      end
    end
  end
end
