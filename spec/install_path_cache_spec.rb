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

  let(:fake_software_config_file) do
    File.join(Omnibus::RSpec::SPEC_DATA, 'software', 'zlib.rb')
  end

  let(:zlib) do
    software = Omnibus::Software.new('', fake_software_config_file, project)
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
    # 13b3f7f2653e40b9d5b393659210775ac5b56f7e0009f82f85b83f5132409362
    #
    # Is the sha256sum of:
    # cat spec/data/software/zlib.rb > t
    # echo -n 'preparation-1.0.0-snoopy-1.0.0' >> t
    # sha256sum t
    it 'returns a tag with the softwares name, version, and hash of deps name+version' do
      expect(ipc.tag).to eql('zlib-1.7.2-13b3f7f2653e40b9d5b393659210775ac5b56f7e0009f82f85b83f5132409362')
    end

    describe 'with no deps' do
      let(:ipc) do
        Omnibus::InstallPathCache.new(install_path, zlib)
      end

      it 'uses the shasum of the software config file' do
        # gsha256sum spec/data/software/zlib.rb
        # 363e6cc2475fcdd6e18b2dc10f6022d1cab498b9961e8225d8a309d18ed3c94b  spec/data/software/zlib.rb
        expect(ipc.tag).to eql('zlib-1.7.2-363e6cc2475fcdd6e18b2dc10f6022d1cab498b9961e8225d8a309d18ed3c94b')
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
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} commit -q -m 'Backup of #{ipc.tag}'")
      ipc.incremental
    end

    it 'tags the software backup' do
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -f '#{ipc.tag}'")
      ipc.incremental
    end
  end

  describe '#restore' do
    let(:git_tag_output) { "#{ipc.tag}\n" }

    let(:tag_cmd) do
      cmd_double = double(Mixlib::ShellOut)
      allow(cmd_double).to receive(:stdout).and_return(git_tag_output)
      allow(cmd_double).to receive(:error!).and_return(cmd_double)
      cmd_double
    end

    before(:each) do
      allow(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l #{ipc.tag}").and_return(tag_cmd)
      allow(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
      allow(ipc).to receive(:create_cache_path)
    end

    it 'creates the cache path' do
      expect(ipc).to receive(:create_cache_path)
      ipc.restore
    end

    it 'checks for a tag with the software and version, and if it finds it, checks it out' do
      expect(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l #{ipc.tag}").and_return(tag_cmd)
      expect(ipc).to receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
      ipc.restore
    end

    describe 'if the tag does not exist' do
      let(:git_tag_output) { "\n" }

      it 'does nothing' do
        expect(ipc).to receive(:shellout).with("git --git-dir=#{cache_path} --work-tree=#{install_path} tag -l #{ipc.tag}").and_return(tag_cmd)
        expect(ipc).to_not receive(:shellout!).with("git --git-dir=#{cache_path} --work-tree=#{install_path} checkout -f '#{ipc.tag}'")
        ipc.restore
      end
    end
  end
end
