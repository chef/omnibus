require 'spec_helper'

module Omnibus
  describe Config do
    it 'extends Mixlib::Config' do
      expect(described_class).to be_a(Mixlib::Config)
    end

    before { described_class.reset }

    shared_examples 'a configurable' do |id, default|
      it "responds to .#{id}" do
        expect(described_class).to have_method_defined(id)
      end

      it ".#{id} defaults to #{default.inspect}" do
        expect(described_class.send(id)).to eq(default)
      end
    end

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
  end
end
