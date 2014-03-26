require 'spec_helper'
require 'omnibus/util'
require 'omnibus/install_path_cache'

describe Omnibus::InstallPathCache do
  let(:install_path) { '/opt/chef' }

  let(:project) do
    raw_project = <<-EOH
name "demo"
install_path "/opt/demo"
build_version "1.0.0"
maintainer 'Chef Software, Inc'
homepage 'http://getchef.com'
dependency 'preparation'
dependency 'snoopy'
dependency 'zlib'
EOH
    project = Omnibus::Project.new(raw_project, 'demo.rb')
    project
  end

  let(:zlib) do
    software = Omnibus::Software.new('', 'zlib.rb', project)
    software.name('zlib')
    software.default_version('1.7.2')
    software
  end

  let(:snoopy) do
    software = Omnibus::Software.new('', 'snoopy.rb', project)
    software.name('snoopy')
    software.default_version('1.0.0')
    software
  end

  let(:preparation) do
    software = Omnibus::Software.new('', 'preparation.rb', project)
    software.name('preparation')
    software.default_version('1.0.0')
    software
  end

  let(:cache_path) { "/var/cache/omnibus/cache/install_path#{install_path}" }

  let(:ipc) do
    project.library.component_added(preparation)
    project.library.component_added(snoopy)
    project.library.component_added(zlib)
    Omnibus::InstallPathCache.new(install_path, zlib)
  end

  describe '#cache_path' do
    it 'returns the install path appended to the install_cache path' do
      expect(ipc.cache_path).to eq('/var/cache/omnibus/cache/install_path/opt/chef')
    end
  end

  describe '#cache_path_exists?' do
    it 'checks for existence' do
      expect(File).to receive(:directory?).with(ipc.cache_path)
      ipc.cache_path_exists?
    end
  end

  describe '#tag' do
    # 9664a7dd4f27909a38769faef7ec739a4d6934f1c2cf95d3112e064682f6a91a
    #
    # Is the sha256sum of 'preparation-1.0.0-snoopy-1.0.0'
    it 'returns a tag with the softwares name, version, and hash of deps name+version' do
      expect(ipc.tag).to eql('zlib-1.7.2-9664a7dd4f27909a38769faef7ec739a4d6934f1c2cf95d3112e064682f6a91a')
    end

    describe 'with no deps' do
      let(:ipc) do
        Omnibus::InstallPathCache.new(install_path, zlib)
      end

      it 'uses the shasum of an empty string' do
        expect(ipc.tag).to eql('zlib-1.7.2-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
      end
    end
  end

  describe '#create_cache_path' do
    it 'runs git init if the cache path does not exist' do
      allow(File).to receive(:directory?).with(ipc.cache_path).and_return(false)
      allow(File).to receive(:directory?).with(File.dirname(ipc.cache_path)).and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(ipc.cache_path))
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} init -q")
      ipc.create_cache_path
    end

    it 'does not run git init if the cache path exists' do
      allow(File).to receive(:directory?).with(ipc.cache_path).and_return(true)
      allow(File).to receive(:directory?).with(File.dirname(ipc.cache_path)).and_return(true)
      expect(ipc).to_not receive(:shellout!).with("git --git-dir=#{cache_path} init -q")
      ipc.create_cache_path
    end
  end

  describe '#incremental' do
    before(:each) do
      allow(ipc).to receive(:shellout!)
      allow(ipc).to receive(:create_cache_path)
    end

    it 'creates the cache path' do
      expect(ipc).to receive(:create_cache_path)
      ipc.incremental
    end

    it 'adds all the changes to git' do
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} add -A -f")
      ipc.incremental
    end

    it 'commits the backup for the software' do
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} commit -m 'Backup of #{ipc.tag}'")
      ipc.incremental
    end

    it 'tags the software backup' do
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -f '#{ipc.tag}'")
      ipc.incremental
    end
  end

  describe '#restore' do
    let(:git_tag_output) { "bread-1.2.2-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\ncoffee-1.2.2-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855-\n#{ipc.tag}\n" }

    let(:tag_cmd) do
      cmd_double = double(Mixlib::ShellOut)
      allow(cmd_double).to receive(:stdout).and_return(git_tag_output)
      allow(cmd_double).to receive(:error!).and_return(cmd_double)
      cmd_double
    end

    before(:each) do
      allow(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l").and_return(tag_cmd)
      allow(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
      allow(ipc).to receive(:create_cache_path)
    end

    it 'creates the cache path' do
      expect(ipc).to receive(:create_cache_path)
      ipc.restore
    end

    it 'checks for a tag with the software and version, and if it finds it, checks it out' do
      expect(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l").and_return(tag_cmd)
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
      ipc.restore
    end

    describe 'if the tag does not exist' do
      let(:git_tag_output) { "bread-1.2.2\ncoffee-1.2.2\n" }

      it 'does nothing' do
        expect(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l").and_return(tag_cmd)
        expect(ipc).to_not receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
        ipc.restore
      end
    end
  end
end
