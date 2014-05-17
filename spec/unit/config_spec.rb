require 'spec_helper'

module Omnibus
  describe Config do
    it 'extends Mixlib::Config' do
      expect(described_class).to be_a(Mixlib::Config)
    end

    it 'extends Util' do
      expect(described_class).to be_a(Util)
    end

    before do
      # Don't expand paths on the build system. Otherwise, you will end up with
      # paths like +\\Users\\you\\Development\\omnibus-ruby\\C:\\omnibus-ruby+
      # when testing on "other" operating systems
      File.stub(:expand_path) { |arg| arg }

      # Make sure we have a clean config
      described_class.reset

      # Prevent Ohai from running
      Ohai.stub(:platform).and_return('linux')
    end

    after do
      # Make sure future tests are clean
      described_class.reset
    end

    shared_examples 'a configurable' do |id, default|
      it "responds to .#{id}" do
        expect(described_class).to have_method_defined(id)
      end

      it ".#{id} defaults to #{default.inspect}" do
        expect(described_class.send(id)).to eq(default)
      end
    end

    include_examples 'a configurable', :base_dir, '/var/cache/omnibus'
    include_examples 'a configurable', :cache_dir, '/var/cache/omnibus/cache'
    include_examples 'a configurable', :install_path_cache_dir, '/var/cache/omnibus/cache/install_path'
    include_examples 'a configurable', :source_dir, '/var/cache/omnibus/src'
    include_examples 'a configurable', :build_dir, '/var/cache/omnibus/build'
    include_examples 'a configurable', :package_dir, '/var/cache/omnibus/pkg'
    include_examples 'a configurable', :package_tmp, '/var/cache/omnibus/pkg-tmp'
    include_examples 'a configurable', :project_root, Dir.pwd
    include_examples 'a configurable', :install_dir, '/opt/chef'
    include_examples 'a configurable', :build_dmg, true
    include_examples 'a configurable', :dmg_window_bounds, '100, 100, 750, 600'
    include_examples 'a configurable', :dmg_pkg_position, '535, 50'
    include_examples 'a configurable', :use_s3_caching, false
    include_examples 'a configurable', :s3_bucket, nil
    include_examples 'a configurable', :s3_access_key, nil
    include_examples 'a configurable', :release_s3_bucket, nil
    include_examples 'a configurable', :release_s3_access_key, nil
    include_examples 'a configurable', :release_s3_secret_key, nil
    include_examples 'a configurable', :override_file, nil
    include_examples 'a configurable', :software_gem, 'omnibus-software'
    include_examples 'a configurable', :solaris_compiler, nil
    include_examples 'a configurable', :append_timestamp, true
    include_examples 'a configurable', :build_retries, 3

    context 'on Windows' do
      before do
        Ohai.stub(:platform).and_return('windows')

        # This is not defined on Linuxy Rubies
        stub_const('File::ALT_SEPARATOR', '\\')
      end

      include_examples 'a configurable', :base_dir, 'C:\\omnibus-ruby'
      include_examples 'a configurable', :cache_dir, 'C:\\omnibus-ruby\\cache'
      include_examples 'a configurable', :install_path_cache_dir, 'C:\\omnibus-ruby\\cache\\install_path'
      include_examples 'a configurable', :source_dir, 'C:\\omnibus-ruby\\src'
      include_examples 'a configurable', :build_dir, 'C:\\omnibus-ruby\\build'
      include_examples 'a configurable', :package_dir, 'C:\\omnibus-ruby\\pkg'
      include_examples 'a configurable', :package_tmp, 'C:\\omnibus-ruby\\pkg-tmp'
    end

    context 'when base_dir is changed' do
      before { described_class.base_dir = '/foo/bar' }

      include_examples 'a configurable', :cache_dir, '/foo/bar/cache'
      include_examples 'a configurable', :install_path_cache_dir, '/foo/bar/cache/install_path'
      include_examples 'a configurable', :source_dir, '/foo/bar/src'
      include_examples 'a configurable', :build_dir, '/foo/bar/build'
      include_examples 'a configurable', :package_dir, '/foo/bar/pkg'
      include_examples 'a configurable', :package_tmp, '/foo/bar/pkg-tmp'
    end
  end
end
