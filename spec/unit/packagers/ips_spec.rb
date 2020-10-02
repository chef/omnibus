require "spec_helper"

module Omnibus
  describe Packager::IPS do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3+20161003185500.git.37.089ab3f")
        project.build_iteration("2")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }
    let(:source_dir)   { File.join(staging_dir, "proto_install") }
    let(:repo_dir)     { File.join(staging_dir, "publish/repo") }
    let(:architecture) { "i86pc" }
    let(:shellout) { double("Mixlib::ShellOut", run_command: true, error!: nil) }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
      create_directory(source_dir)
      create_directory(repo_dir)

      stub_ohai(platform: "solaris2", version: "5.11") do |data|
        data["kernel"]["machine"] = architecture
      end
    end

    describe "#publisher_prefix" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:publisher_prefix)
      end

      it "has a default value" do
        expect(subject.publisher_prefix).to eq("Omnibus")
      end
    end

    it "#id is :IPS" do
      expect(subject.id).to eq(:ips)
    end

    describe "#package_name" do
      it "should create correct package name" do
        expect(subject.package_name).to eq("project-1.2.3+20161003185500.git.37.089ab3f-2.i386.p5p")
      end
    end

    describe "#fmri_package_name" do
      it "should create correct fmri package name" do
        expect(subject.fmri_package_name).to eq ("project@1.2.3,5.11-2")
      end
    end

    describe "#pkg_metadata_file" do
      it "is created inside the staging_dir" do
        expect(subject.pkg_metadata_file).to eq("#{subject.staging_dir}/gen.manifestfile")
      end
    end

    describe "#pkg_manifest_file" do
      it "is created inside the staging_dir" do
        expect(subject.pkg_manifest_file).to eq("#{subject.staging_dir}/#{subject.safe_base_package_name}.p5m")
      end
    end

    describe "#repo_dir" do
      it "is created inside the staging_dir" do
        expect(subject.repo_dir).to eq("#{subject.staging_dir}/publish/repo")
      end
    end

    describe "#source_dir" do
      it "is created inside the staging_dir" do
        expect(subject.source_dir).to eq("#{subject.staging_dir}/proto_install")
      end
    end

    describe "#safe_base_package_name" do
      context 'when the project name is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_base_package_name).to eq("project")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project name has invalid characters" do
        before { project.name("Pro$ject123.for-realz_2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_base_package_name).to eq("pro-ject123.for-realz-2")
          end

          expect(output).to include("The `name' component of IPS package names can only include")
        end
      end
    end

    describe "#safe_architecture" do
      context "the architecture is Intel-based" do
        let(:architecture) { "i86pc" }

        it "returns `i386`" do
          expect(subject.safe_architecture).to eq("i386")
        end
      end

      context "the architecture is SPARC-based" do
        let(:architecture) { "sun4v" }

        it "returns `sparc`" do
          expect(subject.safe_architecture).to eq("sparc")
        end
      end

      context "anything else" do
        let(:architecture) { "FOO" }

        it "returns the value from Ohai" do
          expect(subject.safe_architecture).to eq("FOO")
        end
      end
    end

    describe "#write_versionlock_file" do
      let(:versionlock_file) { File.join(staging_dir, "version-lock") }

      it "creates the version-lock file" do
        subject.write_versionlock_file
        versionlock_file_contents = File.read(versionlock_file)
        expect(versionlock_file_contents).to include("<transform pkg depend -> default facet.version-lock.*> false>")
      end
    end

    describe "#write_transform_file" do
      let(:transform_file) { File.join(staging_dir, "doc-transform") }

      it "creates the transform file" do
        subject.write_transform_file
        transform_file_contents = File.read(transform_file)
        expect(transform_file_contents).to include("<transform dir path=opt$ -> edit group bin sys>")
        expect(transform_file_contents).to include("<transform file depend -> edit pkg.debug.depend.file ruby env>")
        expect(transform_file_contents).to include("<transform file depend -> edit pkg.debug.depend.file make env>")
        expect(transform_file_contents).to include("<transform file depend -> edit pkg.debug.depend.file perl env>")
        expect(transform_file_contents).to include("<transform file depend -> edit pkg.debug.depend.path usr/local/bin usr/bin>")
      end
    end

    describe "#write_pkg_metadata" do
      let(:resources_path) { File.join(tmp_path, "resources/path") }
      let(:manifest_file) { File.join(staging_dir, "gen.manifestfile") }

      it "should create metadata correctly" do
        subject.write_pkg_metadata
        expect(File.exist?(manifest_file)).to be(true)
        manifest_file_contents = File.read(manifest_file)
        expect(manifest_file_contents).to include("set name=pkg.fmri value=developer/versioning/project@1.2.3,5.11-2")
        expect(manifest_file_contents).to include("set name=variant.arch value=i386")
      end

      context "when both symlinks.erb and project-symlinks.erb exists" do
        before do
          FileUtils.mkdir_p(resources_path)
          allow(subject).to receive(:resources_path).and_return(resources_path)
          File.open(File.join(resources_path, "project-symlinks.erb"), "w+") do |f|
            f.puts("link path=usr/bin/ohai target=<%= projectdir %>/bin/ohai")
            f.puts("link path=<%= projectdir %>/bin/gmake target=<%= projectdir %>/embedded/bin/make")
          end
          File.open(File.join(resources_path, "symlinks.erb"), "w+") do |f|
            f.puts("link path=usr/bin/knife target=<%= projectdir %>/bin/knife")
            f.puts("link path=<%= projectdir %>/bin/berks target=<%= projectdir %>/embedded/bin/berks")
          end
        end

        it "should render project-symlinks.erb and append to metadata contents" do
          subject.write_pkg_metadata
          expect(subject.symlinks_file).to eq("project-symlinks.erb")
          expect(File.exist?(manifest_file)).to be(true)
          manifest_file_contents = File.read(manifest_file)
          expect(manifest_file_contents).to include("link path=usr/bin/ohai target=/opt/project/bin/ohai")
          expect(manifest_file_contents).to include("link path=/opt/project/bin/gmake target=/opt/project/embedded/bin/make")
        end
      end

      context "when only symlinks.erb exists" do
        before do
          FileUtils.mkdir_p(resources_path)
          allow(subject).to receive(:resources_path).and_return(resources_path)
          File.open(File.join(resources_path, "symlinks.erb"), "w+") do |f|
            f.puts("link path=usr/bin/knife target=<%= projectdir %>/bin/knife")
            f.puts("link path=<%= projectdir %>/bin/berks target=<%= projectdir %>/embedded/bin/berks")
          end
        end

        it "should render symlinks.erb and append to metadata contents" do
          subject.write_pkg_metadata
          expect(subject.symlinks_file).to eq("symlinks.erb")
          expect(File.exist?(manifest_file)).to be(true)
          manifest_file_contents = File.read(manifest_file)
          expect(manifest_file_contents).to include("link path=usr/bin/knife target=/opt/project/bin/knife")
          expect(manifest_file_contents).to include("link path=/opt/project/bin/berks target=/opt/project/embedded/bin/berks")
        end
      end

      context "when symlinks_file does not exist" do
        it "#write_pkg_metadata does not include symlinks" do
          subject.write_pkg_metadata
          manifest_file = File.join(staging_dir, "gen.manifestfile")
          manifest_file_contents = File.read(manifest_file)
          expect(subject.symlinks_file).to be_nil
          expect(manifest_file_contents).not_to include("link path=usr/bin/ohai target=/opt/project/bin/ohai")
          expect(manifest_file_contents).not_to include("link path=usr/bin/knife target=/opt/project/bin/knife")
        end
      end
    end

    describe "#generate_pkg_contents" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgsend generate #{staging_dir}/proto_install | pkgfmt > #{staging_dir}/project.p5m.1")
        expect(subject).to receive(:shellout!)
          .with("pkgmogrify -DARCH=`uname -p` #{staging_dir}/project.p5m.1 #{staging_dir}/gen.manifestfile #{staging_dir}/doc-transform | pkgfmt > #{staging_dir}/project.p5m.2")
        subject.generate_pkg_contents
      end
    end

    describe "#generate_pkg_deps" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgdepend generate -md #{staging_dir}/proto_install #{staging_dir}/project.p5m.2 | pkgfmt > #{staging_dir}/project.p5m.3")
        expect(subject).to receive(:shellout!)
          .with("pkgmogrify -DARCH=`uname -p` #{staging_dir}/project.p5m.3 #{staging_dir}/doc-transform | pkgfmt > #{staging_dir}/project.p5m.4")
        expect(subject).to receive(:shellout!)
          .with("pkgdepend resolve -m #{staging_dir}/project.p5m.4")
        expect(subject).to receive(:shellout!)
          .with("pkgmogrify #{staging_dir}/project.p5m.4.res #{staging_dir}/version-lock > #{staging_dir}/project.p5m.5.res")
        subject.generate_pkg_deps
      end
    end

    describe "#validate_pkg_manifest" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkglint -c /tmp/lint-cache -r http://pkg.oracle.com/solaris/release #{staging_dir}/project.p5m.5.res")
        subject.validate_pkg_manifest
      end
    end

    describe "#create_ips_repo" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgrepo create #{staging_dir}/publish/repo")
        subject.create_ips_repo
      end
    end

    describe "#publish_ips_pkg" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgrepo -s #{staging_dir}/publish/repo set publisher/prefix=Omnibus")
        expect(subject).to receive(:shellout!)
          .with("pkgsend publish -s #{staging_dir}/publish/repo -d #{staging_dir}/proto_install #{staging_dir}/project.p5m.5.res")

        expect(shellout).to receive(:stdout)
        subject.publish_ips_pkg
      end
    end

    describe "#export_pkg_archive_file" do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgrecv -s #{staging_dir}/publish/repo -a -d #{package_dir}/project-1.2.3+20161003185500.git.37.089ab3f-2.i386.p5p project")

        expect(shellout).to receive(:stdout)
        subject.export_pkg_archive_file
      end
    end

  end
end
