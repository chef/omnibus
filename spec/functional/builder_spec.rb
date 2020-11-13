require "spec_helper"

module Omnibus
  describe Builder do
    include_examples "a software"

    #
    # Fakes the embedded bin path to whatever exists in bundler. This is useful
    # for testing methods like +ruby+ and +rake+ without the need to compile
    # a real Ruby just for functional tests. This strategy does not work on
    # Windows because a) windows doesn't have symlinks and b) the windows
    # omnibus installation has a post installation step that fixes up
    # shebang paths to point to embedded ruby and drops bat files with
    # the correct path. If we need to invoke bundler/appbundler etc. in a
    # manner similar to one that omnibus provides, we would need to emulate
    # the fixup steps here as well, which is a pain the ass.
    #
    # Instead we write batch files that redirect to the batch files
    # corresponding to the system installation and hope it all works out.
    def fake_embedded_bin(name)
      if windows?
        ext = name == "ruby" ? ".exe" : ".bat"
        source = Bundler.which(name + ext)
        raise "Could not find #{name} in bundler environment" unless source

        File.open(File.join(embedded_bin_dir, name + ".bat"), "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            @"#{source}" %*
          EOH
        end
      else
        source = Bundler.which(name)
        raise "Could not find #{name} in bundler environment" unless source

        target = File.join(embedded_bin_dir, name)
        create_link(source, target) unless File.exist?(target)
      end
    end

    def shellout_opts(subject)
      # Pass GEM_HOME and GEM_PATH to subprocess so our fake bin works
      options = {}
      options[:env] = {
          "GEM_HOME" => ENV["GEM_HOME"],
          "GEM_PATH" => ENV["GEM_PATH"],
      }
      options[:env].merge!(subject.with_embedded_path)
      options
    end

    def make_gemspec
      gemspec = File.join(project_dir, "#{project_name}.gemspec")
      File.open(gemspec, "w") do |f|
        f.write <<-EOH.gsub(/^ {12}/, "")
            Gem::Specification.new do |gem|
              gem.name           = '#{project_name}'
              gem.version        = '1.0.0'
              gem.author         = 'Chef Software, Inc.'
              gem.email          = 'info@getchef.com'
              gem.description    = 'Installs a thing'
              gem.summary        = gem.description
            end
        EOH
      end
      gemspec
    end

    def make_gemfile
      gemfile = File.join(project_dir, "Gemfile")
      File.open(gemfile, "w") do |f|
        f.write <<-EOH.gsub(/^ {12}/, "")
            gemspec
        EOH
      end
      gemfile
    end

    def make_gemfile_lock
      gemfile_lock = File.join(project_dir, "Gemfile.lock")
      File.open(gemfile_lock, "w") do |f|
        f.write <<-EOH.gsub(/^ {12}/, "")
            PATH
              remote: .
              specs:
                #{project_name} (1.0.0)

            GEM
              specs:

            PLATFORMS
              ruby

            DEPENDENCIES
              #{project_name}!
        EOH
      end
      gemfile_lock
    end

    subject { described_class.new(software) }
    let(:project_name) { "example" }
    let(:project_dir) { File.join(source_dir, project_name) }

    describe "#command" do
      it "executes the command" do
        subject.command("echo 'Hello World!'")

        output = capture_logging { subject.build }
        expect(output).to include("Hello World")
      end
    end

    describe "#make" do
      it "is waiting for a good samaritan to write tests" do
        skip
      end
    end

    describe "#patch" do
      it "applies the patch" do
        configure = File.join(project_dir, "configure")
        File.open(configure, "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            THING="-e foo"
            ZIP="zap"
          EOH
        end

        patch = File.join(patches_dir, "apply.patch")
        File.open(patch, "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            --- a/configure
            +++ b/configure
            @@ -1,2 +1,3 @@
             THING="-e foo"
            +FOO="bar"
             ZIP="zap"
          EOH
        end

        if windows?
          bash_path = Bundler.which("bash.exe")
          allow(subject).to receive(:embedded_msys_bin)
            .with("bash.exe")
            .and_return("#{bash_path}")
        end

        subject.patch(source: "apply.patch")
        subject.build
      end
    end

    describe "#ruby" do
      it "executes the command as the embdedded ruby" do
        ruby = File.join(scripts_dir, "setup.rb")
        File.open(ruby, "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            File.write("#{software.install_dir}/test.txt", 'This is content!')
          EOH
        end

        fake_embedded_bin("ruby")

        subject.ruby(ruby, env: subject.with_embedded_path)
        subject.build

        path = "#{software.install_dir}/test.txt"
        expect(path).to be_a_file
        expect(File.read(path)).to eq("This is content!")
      end
    end

    describe "#gem" do
      it "executes the command as the embedded gem" do
        make_gemspec
        fake_embedded_bin("gem")
        gem_file = "#{project_name}-1.0.0.gem"

        subject.gem("build #{project_name}.gemspec", shellout_opts(subject))
        subject.gem("install #{gem_file}", shellout_opts(subject))
        output = capture_logging { subject.build }

        expect(File.join(project_dir, gem_file)).to be_a_file
        expect(output).to include("gem build")
        expect(output).to include("gem install")

      end
    end

    describe "#bundler" do
      it "executes the command as the embedded bundler" do
        make_gemspec
        make_gemfile
        fake_embedded_bin("bundle")

        subject.bundle("install", shellout_opts(subject))
        output = capture_logging { subject.build }

        expect(File.join(project_dir, "Gemfile.lock")).to be_a_file
        expect(output).to include("bundle install")
      end
    end

    describe "#appbundle" do
      let(:project) { double("Project") }
      let(:project_softwares) { [ double("Software", name: project_name, project_dir: project_dir) ] }
      it "executes the command as the embedded appbundler" do
        make_gemspec
        make_gemfile
        make_gemfile_lock

        fake_embedded_bin("gem")
        fake_embedded_bin("appbundler")

        subject.gem("build #{project_name}.gemspec", shellout_opts(subject))
        subject.gem("install #{project_name}-1.0.0.gem", shellout_opts(subject))
        subject.appbundle(project_name, shellout_opts(subject))

        expect(subject).to receive(:project).and_return(project)
        expect(project).to receive(:softwares).and_return(project_softwares)

        output = capture_logging { subject.build }

        appbundler_path = File.join(embedded_bin_dir, "appbundler")
        appbundler_path.gsub!(%r{/}, '\\') if windows?
        expect(output).to include("#{appbundler_path} '#{project_dir}' '#{bin_dir}'")
      end
    end

    describe "#rake" do
      it "executes the command as the embedded rake" do
        rakefile = File.join(project_dir, "Rakefile")
        File.open(rakefile, "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            task(:foo) {  }
          EOH
        end

        fake_embedded_bin("rake")

        subject.rake("-T", shellout_opts(subject))
        subject.rake("foo", shellout_opts(subject))
        output = capture_logging { subject.build }

        expect(output).to include("rake -T")
        expect(output).to include("rake foo")
      end
    end

    describe "#block" do
      it "executes the command as a block" do
        subject.block("A complex operation") do
          FileUtils.touch("#{project_dir}/bacon")
        end
        output = capture_logging { subject.build }

        expect(output).to include("A complex operation")
        expect("#{software.project_dir}/bacon").to be_a_file
      end
    end

    describe "#erb" do
      it "renders the erb" do
        erb = File.join(templates_dir, "example.erb")
        File.open(erb, "w") do |f|
          f.write <<-EOH.gsub(/^ {12}/, "")
            <%= a %>
            <%= b %>
          EOH
        end

        destination = File.join(tmp_path, "rendered")

        subject.erb(
          source: "example.erb",
          dest:   destination,
          vars:   { a: "foo", b: "bar" }
        )
        subject.build

        expect(destination).to be_a_file
        expect(File.read(destination)).to eq("foo\nbar\n")
      end
    end

    describe "#mkdir" do
      it "creates the directory" do
        path = File.join(tmp_path, "scratch")
        remove_directory(path)

        subject.mkdir(path)
        subject.build

        expect(path).to be_a_directory
      end
    end

    describe "#touch" do
      it "creates the file" do
        path = File.join(tmp_path, "file")
        remove_file(path)

        subject.touch(path)
        subject.build

        expect(path).to be_a_file
      end

      it "creates the containing directory" do
        path = File.join(tmp_path, "foo", "bar", "file")
        FileUtils.rm_rf(path)

        subject.touch(path)
        subject.build

        expect(path).to be_a_file
      end
    end

    describe "#delete" do
      it "deletes the directory" do
        path = File.join(tmp_path, "scratch")
        create_directory(path)

        subject.delete(path)
        subject.build

        expect(path).to_not be_a_directory
      end

      it "deletes the file" do
        path = File.join(tmp_path, "file")
        create_file(path)

        subject.delete(path)
        subject.build

        expect(path).to_not be_a_file
      end

      it "accepts a glob pattern" do
        path_a = File.join(tmp_path, "file_a")
        path_b = File.join(tmp_path, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.delete("#{tmp_path}/**/file_*")
        subject.build

        expect(path_a).to_not be_a_file
        expect(path_b).to_not be_a_file
      end
    end

    describe "#copy" do
      it "copies the file" do
        path_a = File.join(tmp_path, "file1")
        path_b = File.join(tmp_path, "file2")
        create_file(path_a)

        subject.copy(path_a, path_b)
        subject.build

        expect(path_b).to be_a_file
        expect(File.read(path_b)).to eq(File.read(path_a))
      end

      it "copies the directory and entries" do
        destination = File.join(tmp_path, "destination")

        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        path_a = File.join(directory, "file_a")
        path_b = File.join(directory, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.copy(directory, destination)
        subject.build

        expect(destination).to be_a_directory
        expect("#{destination}/file_a").to be_a_file
        expect("#{destination}/file_b").to be_a_file
      end

      it "accepts a glob pattern" do
        destination = File.join(tmp_path, "destination")
        FileUtils.mkdir_p(destination)

        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        path_a = File.join(directory, "file_a")
        path_b = File.join(directory, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.copy("#{directory}/*", destination)
        subject.build

        expect(destination).to be_a_directory
        expect("#{destination}/file_a").to be_a_file
        expect("#{destination}/file_b").to be_a_file
      end
    end

    describe "#move" do
      it "moves the file" do
        path_a = File.join(tmp_path, "file1")
        path_b = File.join(tmp_path, "file2")
        create_file(path_a)

        subject.move(path_a, path_b)
        subject.build

        expect(path_b).to be_a_file
        expect(path_a).to_not be_a_file
      end

      it "moves the directory and entries" do
        destination = File.join(tmp_path, "destination")

        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        path_a = File.join(directory, "file_a")
        path_b = File.join(directory, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.move(directory, destination)
        subject.build

        expect(destination).to be_a_directory
        expect("#{destination}/file_a").to be_a_file
        expect("#{destination}/file_b").to be_a_file

        expect(directory).to_not be_a_directory
      end

      it "accepts a glob pattern" do
        destination = File.join(tmp_path, "destination")
        FileUtils.mkdir_p(destination)

        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        path_a = File.join(directory, "file_a")
        path_b = File.join(directory, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.move("#{directory}/*", destination)
        subject.build

        expect(destination).to be_a_directory
        expect("#{destination}/file_a").to be_a_file
        expect("#{destination}/file_b").to be_a_file

        expect(directory).to be_a_directory
      end
    end

    describe "#link", :not_supported_on_windows do
      it "links the file" do
        path_a = File.join(tmp_path, "file1")
        path_b = File.join(tmp_path, "file2")
        create_file(path_a)

        subject.link(path_a, path_b)
        subject.build

        expect(path_b).to be_a_symlink
      end

      it "links the directory" do
        destination = File.join(tmp_path, "destination")
        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        subject.link(directory, destination)
        subject.build

        expect(destination).to be_a_symlink
      end

      it "accepts a glob pattern" do
        destination = File.join(tmp_path, "destination")
        FileUtils.mkdir_p(destination)

        directory = File.join(tmp_path, "scratch")
        FileUtils.mkdir_p(directory)

        path_a = File.join(directory, "file_a")
        path_b = File.join(directory, "file_b")
        FileUtils.touch(path_a)
        FileUtils.touch(path_b)

        subject.link("#{directory}/*", destination)
        subject.build

        expect("#{destination}/file_a").to be_a_symlink
        expect("#{destination}/file_b").to be_a_symlink
      end
    end

    describe "#sync" do
      let(:source) do
        source = File.join(tmp_path, "source")
        FileUtils.mkdir_p(source)

        FileUtils.touch(File.join(source, "file_a"))
        FileUtils.touch(File.join(source, "file_b"))
        FileUtils.touch(File.join(source, "file_c"))

        FileUtils.mkdir_p(File.join(source, "folder"))
        FileUtils.touch(File.join(source, "folder", "file_d"))
        FileUtils.touch(File.join(source, "folder", "file_e"))

        FileUtils.mkdir_p(File.join(source, ".dot_folder"))
        FileUtils.touch(File.join(source, ".dot_folder", "file_f"))

        FileUtils.touch(File.join(source, ".file_g"))
        source
      end

      let(:destination) { File.join(tmp_path, "destination") }

      context "when the destination is empty" do
        it "syncs the directories" do
          subject.sync(source, destination)
          subject.build

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file
        end
      end

      context "when the directory exists" do
        before { FileUtils.mkdir_p(destination) }

        it "deletes existing files and folders" do
          FileUtils.mkdir_p("#{destination}/existing_folder")
          FileUtils.mkdir_p("#{destination}/.existing_folder")
          FileUtils.touch("#{destination}/existing_file")
          FileUtils.touch("#{destination}/.existing_file")

          subject.sync(source, destination)
          subject.build

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file

          expect("#{destination}/existing_folder").to_not be_a_directory
          expect("#{destination}/.existing_folder").to_not be_a_directory
          expect("#{destination}/existing_file").to_not be_a_file
          expect("#{destination}/.existing_file").to_not be_a_file
        end
      end

      context "when :exclude is given" do
        it "does not copy files and folders that match the pattern" do
          subject.sync(source, destination, exclude: ".dot_folder")
          subject.build

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to_not be_a_directory
          expect("#{destination}/.dot_folder/file_f").to_not be_a_file
          expect("#{destination}/.file_g").to be_a_file
        end

        it "removes existing files and folders in destination" do
          FileUtils.mkdir_p("#{destination}/existing_folder")
          FileUtils.touch("#{destination}/existing_file")
          FileUtils.mkdir_p("#{destination}/.dot_folder")
          FileUtils.touch("#{destination}/.dot_folder/file_f")

          subject.sync(source, destination, exclude: ".dot_folder")
          subject.build

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to_not be_a_directory
          expect("#{destination}/.dot_folder/file_f").to_not be_a_file
          expect("#{destination}/.file_g").to be_a_file

          expect("#{destination}/existing_folder").to_not be_a_directory
          expect("#{destination}/existing_file").to_not be_a_file
        end
      end
    end

    describe "#update_config_guess", :not_supported_on_windows do
      let(:config_guess_dir) { "#{install_dir}/embedded/lib/config_guess" }

      before do
        FileUtils.mkdir_p(config_guess_dir)
      end

      context "with no config.guess" do
        before do
          File.open("#{config_guess_dir}/config.sub", "w+") do |f|
            f.write("This is config.sub")
          end
        end

        it "fails" do
          subject.update_config_guess
          expect { subject.build }.to raise_error(RuntimeError)
        end
      end

      context "with no config.sub" do
        before do
          File.open("#{config_guess_dir}/config.guess", "w+") do |f|
            f.write("This is config.guess")
          end
        end

        it "fails" do
          subject.update_config_guess
          expect { subject.build }.to raise_error(RuntimeError)
        end
      end

      context "with config_guess dependency" do
        before do
          File.open("#{config_guess_dir}/config.guess", "w+") do |f|
            f.write("This is config.guess")
          end

          File.open("#{config_guess_dir}/config.sub", "w+") do |f|
            f.write("This is config.sub")
          end
        end

        it "update config_guess with defaults" do
          subject.update_config_guess
          subject.build
          expect(File.read("#{project_dir}/config.guess")).to match /config.guess/
          expect(File.read("#{project_dir}/config.sub")).to match /config.sub/
        end

        it "honors :target option" do
          subject.update_config_guess(target: "sub_dir")
          subject.build
          expect(File.read("#{project_dir}/sub_dir/config.guess")).to match /config.guess/
          expect(File.read("#{project_dir}/sub_dir/config.sub")).to match /config.sub/
        end

        it "honors :config_guess in :install option" do
          subject.update_config_guess(install: [:config_guess])
          subject.build
          expect(File.read("#{project_dir}/config.guess")).to match /config.guess/
          expect(File.exist?("#{project_dir}/config.sub")).to be false
        end

        it "honors :config_sub in :install option" do
          subject.update_config_guess(install: [:config_sub])
          subject.build
          expect(File.read("#{project_dir}/config.sub")).to match /config.sub/
          expect(File.exist?("#{project_dir}/config.guess")).to be false
        end
      end
    end
  end
end
