require 'spec_helper'

module Omnibus
  describe Config do
    subject { described_class.instance }

    it 'extends Util' do
      expect(subject).to be_a(Util)
    end

    before do
      # Don't expand paths on the build system. Otherwise, you will end up with
      # paths like +\\Users\\you\\Development\\omnibus-ruby\\C:\\omnibus-ruby+
      # when testing on "other" operating systems
      allow(File).to receive(:expand_path) { |arg| arg }
    end

    shared_examples 'a configurable' do |id, default|
      it "responds to .#{id}" do
        expect(described_class).to respond_to(id)
      end

      it ".#{id} defaults to #{default.inspect}" do
        expect(described_class.send(id)).to eq(default)
      end

      it_behaves_like 'a cleanroom getter', id, default
      it_behaves_like 'a cleanroom setter', id, default
    end

    include_examples 'a configurable', :base_dir, '/var/cache/omnibus'
    include_examples 'a configurable', :cache_dir, '/var/cache/omnibus/cache'
    include_examples 'a configurable', :git_cache_dir, '/var/cache/omnibus/cache/git_cache'
    include_examples 'a configurable', :install_path_cache_dir, '/var/cache/omnibus/cache/git_cache'
    include_examples 'a configurable', :source_dir, '/var/cache/omnibus/src'
    include_examples 'a configurable', :build_dir, '/var/cache/omnibus/build'
    include_examples 'a configurable', :package_dir, '/var/cache/omnibus/pkg'
    include_examples 'a configurable', :package_tmp, '/var/cache/omnibus/pkg-tmp'
    include_examples 'a configurable', :project_root, Dir.pwd
    include_examples 'a configurable', :build_dmg, true
    include_examples 'a configurable', :dmg_window_bounds, '100, 100, 750, 600'
    include_examples 'a configurable', :dmg_pkg_position, '535, 50'
    include_examples 'a configurable', :override_file, nil
    include_examples 'a configurable', :local_software_dirs, []
    include_examples 'a configurable', :software_gem, ['omnibus-software']
    include_examples 'a configurable', :software_gems, ['omnibus-software']
    include_examples 'a configurable', :solaris_compiler, nil
    include_examples 'a configurable', :append_timestamp, true
    include_examples 'a configurable', :build_retries, 3
    include_examples 'a configurable', :use_git_caching, true

    context 'on Windows' do
      before do
        stub_ohai(platform: 'windows', version: '2012')

        # This is not defined on Linuxy Rubies
        stub_const('File::ALT_SEPARATOR', '\\')
      end

      include_examples 'a configurable', :base_dir, 'C:\\omnibus-ruby'
      include_examples 'a configurable', :cache_dir, 'C:\\omnibus-ruby\\cache'
      include_examples 'a configurable', :git_cache_dir, 'C:\\omnibus-ruby\\cache\\git_cache'
      include_examples 'a configurable', :install_path_cache_dir, 'C:\\omnibus-ruby\\cache\\git_cache'
      include_examples 'a configurable', :source_dir, 'C:\\omnibus-ruby\\src'
      include_examples 'a configurable', :build_dir, 'C:\\omnibus-ruby\\build'
      include_examples 'a configurable', :package_dir, 'C:\\omnibus-ruby\\pkg'
      include_examples 'a configurable', :package_tmp, 'C:\\omnibus-ruby\\pkg-tmp'
    end

    context 'when base_dir is changed' do
      before { described_class.base_dir('/foo/bar') }

      include_examples 'a configurable', :cache_dir, '/foo/bar/cache'
      include_examples 'a configurable', :git_cache_dir, '/foo/bar/cache/git_cache'
      include_examples 'a configurable', :install_path_cache_dir, '/foo/bar/cache/git_cache'
      include_examples 'a configurable', :source_dir, '/foo/bar/src'
      include_examples 'a configurable', :build_dir, '/foo/bar/build'
      include_examples 'a configurable', :package_dir, '/foo/bar/pkg'
      include_examples 'a configurable', :package_tmp, '/foo/bar/pkg-tmp'
    end

    context '#install_path_cache_dir' do
      it 'is deprecated' do
        expect(Omnibus.logger).to receive(:deprecated).with('Config')
        described_class.install_path_cache_dir
      end

      it 'defaults to #git_cache_dir' do
        expect(described_class.install_path_cache_dir).to eq(described_class.git_cache_dir)
      end

      it 'overrides the value of #git_cache_dir when specified' do
        path = '/magical/path/with/ponies'
        described_class.install_path_cache_dir(path)
        expect(described_class.git_cache_dir).to eq(path)
      end
    end
  end
end
