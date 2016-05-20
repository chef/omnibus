require "spec_helper"

module Omnibus
  describe Packager::Solaris do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("1")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }
    let(:architecture) { "i86pc" }

    before do
      # This is here to allow this unit test to run on windows.
      allow(File).to receive(:expand_path).and_wrap_original do |m, *args|
        m.call(*args).sub(/^[A-Za-z]:/, "")
      end
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)

      stub_ohai(platform: "solaris2", version: "5.11") do |data|
        data["kernel"]["machine"] = architecture
      end
    end

    describe '#id' do
      it "is :solaris" do
        expect(subject.id).to eq(:solaris)
      end
    end

    describe '#package_name' do
      it "includes the name, version, iteration and architecture" do
        expect(subject.package_name).to eq("project-1.2.3-1.i386.solaris")
      end
    end

    describe '#pkgmk_version' do
      it "includes the version and iteration" do
        expect(subject.pkgmk_version).to eq("1.2.3-1")
      end
    end

    describe '#install_dirname' do
      it "returns the parent directory" do
        expect(subject.install_dirname).to eq("/opt")
      end
    end

    describe '#install_basename' do
      it "name of the install directory" do
        expect(subject.install_basename).to eq("project")
      end
    end

    describe '#write_scripts' do
      context "when scripts are given" do
        let(:scripts) { %w{ postinstall postremove } }
        before do
          scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it "writes the scripts into scripts staging dir" do
          subject.write_scripts

          scripts.each do |script_name|
            script_file = "#{staging_dir}/#{script_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end

      context "when scripts with default omnibus naming are given" do
        let(:default_scripts) { %w{ postinst postrm } }
        before do
          default_scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it "writes the scripts into scripts staging dir" do
          subject.write_scripts

          default_scripts.each do |script_name|
            mapped_name = Packager::Solaris::SCRIPT_MAP[script_name.to_sym]
            script_file = "#{staging_dir}/#{mapped_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end
    end

    describe '#write_prototype_file' do
      let(:prototype_file) { File.join(staging_dir, "Prototype") }

      before do
        allow(subject).to receive(:shellout!)
        File.open("#{staging_dir}/files", "w+") do |f|
          f.write <<-EOF
/foo/bar/baz
/a file with spaces
          EOF
        end
      end

      it "creates the prototype file" do
        subject.write_prototype_file
        contents = File.read(prototype_file)

        expect(contents).to include(
          <<-EOH.gsub(/^ {12}/, "")
            i pkginfo
            i postinstall
            i postremove
          EOH
        )
      end

      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("cd /opt && find project -print > #{File.join(staging_dir, 'files')}")
        expect(subject).to receive(:shellout!)
          .with("cd /opt && pkgproto < #{File.join(staging_dir, 'files.clean')} > #{File.join(staging_dir, 'Prototype.files')}")
        expect(subject).to receive(:shellout!)
          .with("awk '{ $5 = \"root\"; $6 = \"root\"; print }' < #{File.join(staging_dir, 'Prototype.files')} >> #{File.join(staging_dir, 'Prototype')}")
        subject.write_prototype_file
      end

      it "strips out the file with spaces from files.clean" do
        subject.write_prototype_file
        contents = File.read(File.join(staging_dir, "files.clean"))
        expect(contents).not_to include("a file with spaces")
        expect(contents).to include("/foo/bar/baz")
      end
    end

    describe '#create_solaris_file' do
      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgmk -o -r /opt -d #{staging_dir} -f #{File.join(staging_dir, 'Prototype')}")
        expect(subject).to receive(:shellout!)
          .with("pkgchk -vd #{staging_dir} project")
        expect(subject).to receive(:shellout!)
          .with("pkgtrans #{staging_dir} #{File.join(package_dir, 'project-1.2.3-1.i386.solaris')} project")

        subject.create_solaris_file
      end
    end

    describe '#write_pkginfo_file' do
      let(:pkginfo_file) { File.join(staging_dir, "pkginfo") }
      let(:hostname) { Socket.gethostname }
      let(:now) { Time.now }

      it "generates the file" do
        subject.write_pkginfo_file
        expect(pkginfo_file).to be_a_file
      end

      it "has the correct content" do
        allow(Time).to receive(:now).and_return(now)
        subject.write_pkginfo_file
        contents = File.read(pkginfo_file)

        expect(contents).to include("CLASSES=none")
        expect(contents).to include("TZ=PST")
        expect(contents).to include("PATH=/sbin:/usr/sbin:/usr/bin:/usr/sadm/install/bin")
        expect(contents).to include("BASEDIR=/opt")
        expect(contents).to include("PKG=project")
        expect(contents).to include("NAME=project")
        expect(contents).to include("ARCH=i386")
        expect(contents).to include("VERSION=1.2.3-1")
        expect(contents).to include("CATEGORY=application")
        expect(contents).to include("DESC=")
        expect(contents).to include("VENDOR=Chef Software")
        expect(contents).to include("EMAIL=Chef Software")
        expect(contents).to include("PSTAMP=#{hostname}#{now.utc.iso8601}")
      end
    end

    describe '#create_solaris_file' do
      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
      end

      it "uses the correct commands" do
        expect(subject).to receive(:shellout!)
          .with("pkgmk -o -r /opt -d #{staging_dir} -f #{File.join(staging_dir, 'Prototype')}")
        expect(subject).to receive(:shellout!)
          .with("pkgchk -vd #{staging_dir} project")
        expect(subject).to receive(:shellout!)
          .with("pkgtrans #{staging_dir} #{File.join(package_dir, 'project-1.2.3-1.i386.solaris')} project")

        subject.create_solaris_file
      end
    end

    describe '#safe_architecture' do
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
  end
end
