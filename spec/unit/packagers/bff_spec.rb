require "spec_helper"

module Omnibus
  describe Packager::BFF do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }

    before do
      # This is here to allow this unit test to run on windows.
      allow(File).to receive(:expand_path).and_wrap_original do |m, *args|
        m.call(*args).sub(/^[A-Za-z]:/, "")
      end
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
      create_directory(subject.scripts_staging_dir)
    end

    describe '#id' do
      it "is :bff" do
        expect(subject.id).to eq(:bff)
      end
    end

    describe '#package_name' do
      before do
        allow(subject).to receive(:safe_architecture).and_return("x86_64")
      end

      it "includes the name and version" do
        expect(subject.package_name).to eq("project-1.2.3-2.x86_64.bff")
      end
    end

    describe '#scripts_install_dir' do
      it "is nested inside the project install_dir" do
        expect(subject.scripts_install_dir).to start_with(project.install_dir)
      end
    end

    describe '#scripts_staging_dir' do
      it "is nested inside the staging_dir" do
        expect(subject.scripts_staging_dir).to start_with(staging_dir)
      end
    end

    describe '#write_scripts' do
      context "when scripts are given" do
        let(:scripts) { %w{ preinst postinst prerm postrm } }
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
            script_file = "#{subject.scripts_staging_dir}/#{script_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end
    end

    describe '#write_gen_template' do
      before do
        allow(subject).to receive(:safe_architecture).and_return("x86_64")
      end

      let(:gen_file) { "#{staging_dir}/gen.template" }

      it "generates the file" do
        subject.write_gen_template
        expect(gen_file).to be_a_file
      end

      it "has the correct content" do
        subject.write_gen_template
        contents = File.read(gen_file)

        expect(contents).to include("Package Name: project")
        expect(contents).to include("Package VRMF: 1.2.3.2")
        expect(contents).to include("Update: N")
        expect(contents).to include("Fileset")
        expect(contents).to include("  Fileset Name: project")
        expect(contents).to include("  Fileset VRMF: 1.2.3.2")
        expect(contents).to include("  Fileset Description: The full stack of project")
        expect(contents).to include("  USRLIBLPPFiles")
        expect(contents).to include("  EOUSRLIBLPPFiles")
        expect(contents).to include("  Bosboot required: N")
        expect(contents).to include("  License agreement acceptance required: N")
        expect(contents).to include("  Include license files in this package: N")
        expect(contents).to include("  Requisites:")
        expect(contents).to include("  ROOT Part: Y")
        expect(contents).to include("  USRFiles")
        expect(contents).to include("  EOUSRFiles")
        expect(contents).to include("EOFileset")
      end

      context "when files and directories are present" do
        before do
          create_file("#{staging_dir}/.file1")
          create_file("#{staging_dir}/file2")
          create_directory("#{staging_dir}/.dir1")
          create_directory("#{staging_dir}/dir2")
        end

        it "writes them into the template" do
          subject.write_gen_template
          contents = File.read(gen_file)

          expect(contents).to include("/.dir1")
          expect(contents).to include("/.file1")
          expect(contents).to include("/dir2")
          expect(contents).to include("/file2")
        end
      end

      context "when paths with colons/commas are present", if: !windows? do
        let(:contents) do
          subject.write_gen_template
          File.read(gen_file)
        end

        before do
          create_file("#{staging_dir}/man3/App::Cpan.3")
          create_file("#{staging_dir}/comma,file")
          create_directory("#{staging_dir}/colon::dir/file")
          create_directory("#{staging_dir}/comma,dir/file")
        end

        it "renames colon filenames in the template" do
          expect(contents).to include("/man3/App____Cpan.3")
        end

        it "renames colon directory names in the template" do
          expect(contents).to include("/colon____dir/file")
        end

        it "renames comma filenames in the template" do
          expect(contents).to include("/comma__file")
        end

        it "renames comma directory names in the template" do
          expect(contents).to include("/comma__dir/file")
        end

        context "creates a config script" do
          it 'when there wasn\'t one provided' do
            FileUtils.rm_f("#{subject.scripts_staging_dir}/config")
            subject.write_gen_template
            expect(File).to exist("#{subject.scripts_staging_dir}/config")
          end

          it 'when one is provided in the project\'s def' do
            create_file("#{project_root}/package-scripts/project/config")
            subject.write_gen_template
            contents = File.read("#{subject.scripts_staging_dir}/config")
            expect(contents).to include("mv '/man3/App____Cpan.3' '/man3/App::Cpan.3'")
          end

          it "with mv commands for all the renamed files" do
            subject.write_gen_template
            contents = File.read("#{subject.scripts_staging_dir}/config")
            expect(contents).to include("mv '/man3/App____Cpan.3' '/man3/App::Cpan.3'")
            expect(contents).to include("mv '/comma__file' '/comma,file'")
            expect(contents).to include("mv '/colon____dir/file' '/colon::dir/file'")
            expect(contents).to include("mv '/comma__dir/file' '/comma,dir/file'")
          end
        end
      end

      context "when script files are present" do
        before do
          create_file("#{subject.scripts_staging_dir}/preinst")
          create_file("#{subject.scripts_staging_dir}/postinst")
          create_file("#{subject.scripts_staging_dir}/prerm")
          create_file("#{subject.scripts_staging_dir}/postrm")
          create_file("#{subject.scripts_staging_dir}/config")
        end

        it "writes them into the template" do
          subject.write_gen_template
          contents = File.read(gen_file)

          expect(contents).to include("    Pre-installation Script: #{subject.scripts_staging_dir}/preinst")
          expect(contents).to include("    Post-installation Script: #{subject.scripts_staging_dir}/postinst")
          expect(contents).to include("    Configuration Script: #{subject.scripts_staging_dir}/config")
          expect(contents).to include("    Pre_rm Script: #{subject.scripts_staging_dir}/prerm")
          expect(contents).to include("    Unconfiguration Script: #{subject.scripts_staging_dir}/postrm")
        end
      end

      context "when the log_level is :debug, it" do
        before do
          Omnibus.logger.level = :debug
        end

        it "prints the rendered template" do
          output = capture_logging { subject.write_gen_template }
          expect(output).to include("Package Name: project")
        end
      end
    end

    describe '#create_bff_file' do
      # Need to mock out the id calls
      let(:id_shellout) {
        shellout_mock = double("shellout_mock")
        allow(shellout_mock).to receive(:stdout).and_return("300")
        shellout_mock
      }

      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
        allow(subject).to receive(:shellout!)
          .with("id -u").and_return(id_shellout)
        allow(subject).to receive(:shellout!)
          .with("id -g").and_return(id_shellout)

        create_file(File.join(staging_dir, ".info", "#{project.name}.inventory")) {
          <<-INVENTORY.gsub(/^\s{12}/, "")
            /opt/project/version-manifest.txt:
                      owner = root
                      group = system
                      mode = 644
                      type = FILE
                      class = apply,inventory,angry-omnibus-toolchain
                      size = 1906
                      checksum = "02776    2 "
          INVENTORY
        }
        create_file("#{staging_dir}/file") { "http://goo.gl/TbkO01" }
      end

      it "gets the build uid" do
        expect(subject).to receive(:shellout!)
          .with("id -u")
        subject.create_bff_file
      end

      it "gets the build gid" do
        expect(subject).to receive(:shellout!)
          .with("id -g")
        subject.create_bff_file
      end

      it "chowns the directory to root" do
        # A note - the /opt/ here is essentially project.install_dir one level up.
        # There is nothing magical about 'opt' as a directory.
        expect(subject).to receive(:shellout!)
          .with(/chown -Rh 0:0 #{staging_dir}\/opt$/)
        subject.create_bff_file
      end

      it "logs a message" do
        output = capture_logging { subject.create_bff_file }
        expect(output).to include("Creating .bff file")
      end

      it "uses the correct command" do
        expect(subject).to receive(:shellout!)
          .with(/\/usr\/sbin\/mkinstallp -d/)
        subject.create_bff_file
      end

      it "chowns the directory back to the build user" do
        # A note - the /opt/ here is essentially project.install_dir one level up.
        # There is nothing magical about 'opt' as a directory.
        # 300 is just what we set the mock for the build uid/gid to return.
        expect(subject).to receive(:shellout!)
          .with(/chown -Rh 300:300 #{staging_dir}/)
        subject.create_bff_file
      end

      context "when the log_level is :debug, it" do
        before do
          Omnibus.logger.level = :debug
        end

        it "prints the inventory file" do
          output = capture_logging { subject.create_bff_file }
          expect(output).to match(%r{^/opt/project})
        end
      end
    end

    describe '#safe_base_package_name' do
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

          expect(output).to include("The `name' component of BFF package names can only include")
        end
      end
    end

    describe '#create_bff_file_name' do
      it "constructs the proper package name" do
        expect(subject.create_bff_file_name).to eq("project-1.2.3-2.x86_64.bff")
      end

    end

    describe '#bff_version' do
      it "returns the build version up with the build iteration" do
        expect(subject.bff_version).to eq("1.2.3.2")
      end
    end

    describe '#safe_architecture' do
      before do
        stub_ohai(platform: "ubuntu", version: "12.04") do |data|
          data["kernel"]["machine"] = "i386"
        end
      end

      it "returns the value from Ohai" do
        expect(subject.safe_architecture).to eq("i386")
      end
    end
  end
end
