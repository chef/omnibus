require "spec_helper"

module Omnibus
  describe GitCache do
    let(:project) do
      Project.new("/path/to/demo.rb").evaluate do
        name "demo"
        install_dir "/opt/demo"

        build_version "1.0.0"

        maintainer "Chef Software, Inc"
        homepage "http://getchef.com"

        dependency "preparation"
        dependency "snoopy"
        dependency "zlib"
      end
    end

    let(:install_dir) { project.install_dir }

    let(:zlib) do
      Software.new(project, "zlib.rb").evaluate do
        name "zlib"
        default_version "1.7.2"
      end
    end

    let(:snoopy) do
      Software.new(project, "snoopy.rb").evaluate do
        name "snoopy"
        default_version "1.0.0"
      end
    end

    let(:preparation) do
      Software.new(project, "preparation.rb").evaluate do
        name "preparation"
        default_version "1.0.0"
      end
    end

    let(:cache_path) { File.join("/var/cache/omnibus/cache/git_cache", install_dir) }

    let(:cache_serial_number) { described_class::SERIAL_NUMBER }

    let(:ipc) do
      project.library.component_added(preparation)
      project.library.component_added(snoopy)
      project.library.component_added(zlib)
      described_class.new(zlib)
    end

    describe '#cache_path' do
      it "returns the install path appended to the install_cache path" do
        expect(ipc.cache_path).to eq(cache_path)
      end
    end

    describe '#tag' do
      it "returns the correct tag" do
        expect(ipc.tag).to eql("zlib-24a8ec71da04059dcf7ed3c6e8e0fd9d155476abe4b5156d1f13c42e85478c2b-#{cache_serial_number}")
      end

      describe "with no deps" do
        let(:ipc) do
          described_class.new(zlib)
        end

        it "returns the correct tag" do
          expect(ipc.tag).to eql("zlib-ee71fc1a512f03b9dd46c1fd9b5ab71fcc51b638857bf328496a31abb2654c2b-#{cache_serial_number}")
        end
      end
    end

    describe '#create_cache_path' do
      it "runs git init if the cache path does not exist" do
        allow(File).to receive(:directory?)
          .with(ipc.cache_path)
          .and_return(false)
        allow(File).to receive(:directory?)
          .with(File.dirname(ipc.cache_path))
          .and_return(false)
        expect(FileUtils).to receive(:mkdir_p)
          .with(File.dirname(ipc.cache_path))
        expect(ipc).to receive(:shellout!)
          .with("git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} init -q")
        ipc.create_cache_path
      end

      it "does not run git init if the cache path exists" do
        allow(File).to receive(:directory?)
          .with(ipc.cache_path)
          .and_return(true)
        allow(File).to receive(:directory?)
          .with(File.dirname(ipc.cache_path))
          .and_return(true)
        expect(ipc).to_not receive(:shellout!)
        ipc.create_cache_path
      end
    end

    describe '#incremental' do
      before(:each) do
        allow(ipc).to receive(:shellout!)
        allow(ipc).to receive(:create_cache_path)
      end

      it "creates the cache path" do
        expect(ipc).to receive(:create_cache_path)
        ipc.incremental
      end

      it "adds all the changes to git removing git directories" do
        expect(ipc).to receive(:remove_git_dirs)
        expect(ipc).to receive(:shellout!)
          .with("git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} add -A -f")
        ipc.incremental
      end

      it "commits the backup for the software" do
        expect(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} commit -q -m "Backup of #{ipc.tag}"})
        ipc.incremental
      end

      it "tags the software backup" do
        expect(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} tag -f "#{ipc.tag}"})
        ipc.incremental
      end
    end

    describe '#remove_git_dirs' do
      let(:git_files) { ["git/HEAD", "git/description", "git/hooks", "git/info", "git/objects", "git/refs" ] }
      it "removes bare git directories" do
        allow(Dir).to receive(:glob).and_return(["git/config"])
        git_files.each do |git_file|
          expect(File).to receive(:exist?).with(git_file).and_return(true)
        end
        allow(File).to receive(:dirname).and_return("git")
        expect(FileUtils).to receive(:rm_rf).with("git")

        ipc.remove_git_dirs
      end

      it "does ignores non git directories" do
        allow(Dir).to receive(:glob).and_return(["not_git/config"])
        expect(File).to receive(:exist?).with("not_git/HEAD").and_return(false)
        allow(File).to receive(:dirname).and_return("not_git")
        expect(FileUtils).not_to receive(:rm_rf).with("not_git")

        ipc.remove_git_dirs
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
        allow(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} tag -l "#{ipc.tag}"})
          .and_return(tag_cmd)
        allow(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} checkout -f "#{ipc.tag}"})
        allow(ipc).to receive(:create_cache_path)
      end

      it "creates the cache path" do
        expect(ipc).to receive(:create_cache_path)
        ipc.restore
      end

      it "checks for a tag with the software and version, and if it finds it, checks it out" do
        expect(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} tag -l "#{ipc.tag}"})
          .and_return(tag_cmd)
        expect(ipc).to receive(:shellout!)
          .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} checkout -f "#{ipc.tag}"})
        ipc.restore
      end

      describe "if the tag does not exist" do
        let(:git_tag_output) { "\n" }

        it "does nothing" do
          expect(ipc).to receive(:shellout!)
            .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} tag -l "#{ipc.tag}"})
            .and_return(tag_cmd)
          expect(ipc).to_not receive(:shellout!)
            .with(%Q{git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} checkout -f "#{ipc.tag}"})
          ipc.restore
        end
      end
    end
  end
end
