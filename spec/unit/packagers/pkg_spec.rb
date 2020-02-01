require "spec_helper"

module Omnibus
  describe Packager::PKG do
    let(:project) do
      Project.new.tap do |project|
        project.name("project-full-name")
        project.homepage("https://example.com")
        project.install_dir("/opt/project-full-name")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project-full-name/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }

    before do
      subject.identifier("com.getchef.project-full-name")

      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
      create_directory("#{staging_dir}/Scripts")
    end

    describe "DSL" do
      it "exposes :identifier" do
        expect(subject).to have_exposed_method(:identifier)
      end

      it "exposes :signing_identity" do
        expect(subject).to have_exposed_method(:signing_identity)
      end
    end

    describe "#id" do
      it "is :pkg" do
        expect(subject.id).to eq(:pkg)
      end
    end

    describe "#package_name" do
      it "includes the name, version, and build iteration" do
        expect(subject.package_name).to eq("project-full-name-1.2.3-2.pkg")
      end
    end

    describe "#resources_dir" do
      it "is nested inside the staging_dir" do
        expect(subject.resources_dir).to eq("#{staging_dir}/Resources")
      end
    end

    describe "#scripts_dir" do
      it "is nested inside the staging_dir" do
        expect(subject.scripts_dir).to eq("#{staging_dir}/Scripts")
      end
    end

    describe "#write_scripts" do
      context "when scripts are given" do
        let(:scripts) { %w{ preinstall postinstall } }
        before do
          scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project-full-name/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it "writes the scripts into scripts staging dir" do
          subject.write_scripts

          scripts.each do |script_name|
            script_file = "#{staging_dir}/Scripts/#{script_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end

      context "when scripts with default omnibus naming are given" do
        let(:default_scripts) { %w{ preinst postinst } }
        before do
          default_scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project-full-name/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it "writes the scripts into scripts staging dir" do
          subject.write_scripts

          default_scripts.each do |script_name|
            mapped_name = Packager::PKG::SCRIPT_MAP[script_name.to_sym]
            script_file = "#{staging_dir}/Scripts/#{mapped_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end
    end

    describe "#sign_software_libs_and_bins" do
      context "when pkg signing is disabled" do
        it "does not sign anything" do
          expect(subject).not_to receive(:sign_binary)
          expect(subject).not_to receive(:sign_library)
          subject.sign_software_libs_and_bins
        end

        it "returns an empty set" do
          expect(subject.sign_software_libs_and_bins).to be_nil
        end
      end

      context "when pkg signing is enabled" do
        before do
          subject.signing_identity("My Special Identity")
        end

        context "without software" do
          it "does not sign anything" do
            expect(subject).not_to receive(:sign_binary)
            expect(subject).not_to receive(:sign_library)
            subject.sign_software_libs_and_bins
          end

          it "returns an empty set" do
            expect(subject.sign_software_libs_and_bins).to eq(Set.new)
          end
        end

        context "project with software" do
          let(:software) do
            Software.new(project).tap do |software|
              software.name("software-full-name")
            end
          end

          before do
            allow(project).to receive(:softwares).and_return([software])
          end

          context "with empty bin_dirs and lib_dirs" do
            before do
              allow(software).to receive(:lib_dirs).and_return([])
              allow(software).to receive(:bin_dirs).and_return([])
            end

            it "does not sign anything" do
              expect(subject).not_to receive(:sign_binary)
              expect(subject).not_to receive(:sign_library)
              subject.sign_software_libs_and_bins
            end

            it "returns an empty set" do
              expect(subject.sign_software_libs_and_bins).to eq(Set.new)
            end
          end

          context "with default bin_dirs and lib_dirs" do
            context "with binaries" do
              let(:bin) { "/opt/#{project.name}/bin/test_bin" }
              let(:embedded_bin) { "/opt/#{project.name}/embedded/bin/test_bin" }
              before do
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/bin/*").and_return([bin])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/bin/*").and_return([embedded_bin])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/lib/*").and_return([])
                allow(subject).to receive(:is_binary?).with(bin).and_return(true)
                allow(subject).to receive(:is_binary?).with(embedded_bin).and_return(true)
                allow(subject).to receive(:find_linked_libs).with(bin).and_return([])
                allow(subject).to receive(:find_linked_libs).with(embedded_bin).and_return([])
                allow(subject).to receive(:sign_binary).with(bin, true)
                allow(subject).to receive(:sign_binary).with(embedded_bin, true)
              end

              it "signs the binaries" do
                expect(subject).to receive(:sign_binary).with(bin, true)
                expect(subject).to receive(:sign_binary).with(embedded_bin, true)
                subject.sign_software_libs_and_bins
              end

              it "returns a set with the signed binaries" do
                expect(subject.sign_software_libs_and_bins).to eq(Set.new [bin, embedded_bin])
              end
            end

            context "with library" do
              let(:lib) { "/opt/#{project.name}/embedded/lib/test_lib" }
              before do
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/bin/*").and_return([])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/bin/*").and_return([])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/lib/*").and_return([lib])
                allow(subject).to receive(:is_macho?).with(lib).and_return(true)
                allow(subject).to receive(:find_linked_libs).with(lib).and_return([])
                allow(subject).to receive(:sign_library).with(lib)
              end

              it "signs the library" do
                expect(subject).to receive(:sign_library).with(lib)
                subject.sign_software_libs_and_bins
              end
            end

            context "with binaries and libraries with linked libs" do
              let(:bin) { "/opt/#{project.name}/bin/test_bin" }
              let(:bin2) { "/opt/#{project.name}/bin/test_bin2" }
              let(:embedded_bin) { "/opt/#{project.name}/embedded/bin/test_bin" }
              let(:lib) { "/opt/#{project.name}/embedded/lib/test_lib" }
              let(:lib2) { "/opt/#{project.name}/embedded/lib/test_lib2" }
              before do
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/bin/*").and_return([bin, bin2])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/bin/*").and_return([embedded_bin])
                allow(Dir).to receive(:[]).with("/opt/#{project.name}/embedded/lib/*").and_return([lib])
                allow(subject).to receive(:is_binary?).with(bin).and_return(true)
                allow(subject).to receive(:is_binary?).with(bin2).and_return(true)
                allow(subject).to receive(:is_binary?).with(embedded_bin).and_return(true)
                allow(subject).to receive(:is_macho?).with(lib).and_return(true)
                allow(subject).to receive(:is_macho?).with(lib2).and_return(true)
                allow(subject).to receive(:find_linked_libs).with(bin).and_return([lib2])
                allow(subject).to receive(:find_linked_libs).with(bin2).and_return([])
                allow(subject).to receive(:find_linked_libs).with(embedded_bin).and_return([])
                allow(subject).to receive(:find_linked_libs).with(lib).and_return([])
                allow(subject).to receive(:find_linked_libs).with(lib2).and_return([])
                allow(subject).to receive(:sign_binary).with(bin, true)
                allow(subject).to receive(:sign_binary).with(bin2, true)
                allow(subject).to receive(:sign_binary).with(embedded_bin, true)
                allow(subject).to receive(:sign_library).with(lib)
                allow(subject).to receive(:sign_library).with(lib2)
                allow(Digest::SHA256).to receive(:file).with(bin).and_return(Digest::SHA256.new.update(bin))
                allow(Digest::SHA256).to receive(:file).with(bin2).and_return(Digest::SHA256.new.update(bin2))
                allow(Digest::SHA256).to receive(:file).with(embedded_bin).and_return(Digest::SHA256.new.update(embedded_bin))
                allow(Digest::SHA256).to receive(:file).with(lib).and_return(Digest::SHA256.new.update(lib))
                allow(Digest::SHA256).to receive(:file).with(lib2).and_return(Digest::SHA256.new.update(lib2))
              end

              it "signs the binaries" do
                expect(subject).to receive(:sign_binary).with(bin, true)
                expect(subject).to receive(:sign_binary).with(bin2, true)
                expect(subject).to receive(:sign_binary).with(embedded_bin, true)
                subject.sign_software_libs_and_bins
              end

              it "signs the libraries" do
                expect(subject).to receive(:sign_library).with(lib)
                expect(subject).to receive(:sign_library).with(lib2)
                subject.sign_software_libs_and_bins
              end
            end
          end
        end
      end
    end

    describe "#build_component_pkg" do
      it "executes the pkgbuild command" do
        expect(subject).to receive(:shellout!).with <<-EOH.gsub(/^ {10}/, "")
          pkgbuild \\
            --identifier "com.getchef.project-full-name" \\
            --version "1.2.3" \\
            --scripts "#{staging_dir}/Scripts" \\
            --root "/opt/project-full-name" \\
            --install-location "/opt/project-full-name" \\
            --preserve-xattr \\
            "project-full-name-core.pkg"
        EOH

        subject.build_component_pkg
      end
    end

    describe "#write_distribution_file" do
      it "generates the file" do
        subject.write_distribution_file
        expect("#{staging_dir}/Distribution").to be_a_file
      end

      it "has the correct content" do
        subject.write_distribution_file
        contents = File.read("#{staging_dir}/Distribution")

        expect(contents).to include('<pkg-ref id="com.getchef.project-full-name"/>')
        expect(contents).to include('<line choice="com.getchef.project-full-name"/>')
        expect(contents).to include("project-full-name-core.pkg")
      end
    end

    describe "#build_product_pkg" do
      context "when pkg signing is disabled" do
        it "generates the distribution and runs productbuild" do
          expect(subject).to receive(:shellout!).with <<-EOH.gsub(/^ {12}/, "")
            productbuild \\
              --distribution "#{staging_dir}/Distribution" \\
              --resources "#{staging_dir}/Resources" \\
              "#{package_dir}/project-full-name-1.2.3-2.pkg"
          EOH

          subject.build_product_pkg
        end
      end

      context "when pkg signing is enabled" do
        before do
          subject.signing_identity("My Special Identity")
        end

        it "includes the signing parameters in the product build command" do
          expect(subject).to receive(:shellout!).with <<-EOH.gsub(/^ {12}/, "")
            productbuild \\
              --distribution "#{staging_dir}/Distribution" \\
              --resources "#{staging_dir}/Resources" \\
              --sign "My Special Identity" \\
              "#{package_dir}/project-full-name-1.2.3-2.pkg"
          EOH
          subject.build_product_pkg
        end
      end

      context "when the identifier isn't specified by the project" do
        before do
          subject.identifier(nil)
          project.name("$Project#")
        end

        it "uses com.example.PROJECT_NAME as the identifier" do
          expect(subject.safe_identifier).to eq("test.chefsoftware.pkg.project")
        end
      end
    end

    describe "#component_pkg" do
      it "returns the project name with -core.pkg" do
        expect(subject.component_pkg).to eq("project-full-name-core.pkg")
      end
    end

    describe "#safe_base_package_name" do
      context 'when the project name is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_base_package_name).to eq("project-full-name")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project name has invalid characters" do
        before { project.name("$Project123.for-realz_2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_base_package_name).to eq("project123forrealz2")
          end

          expect(output).to include("The `name' component of Mac package names can only include")
        end
      end
    end

    describe "#safe_identifier" do
      context "when Project#identifier is given" do
        before { subject.identifier("com.apple.project") }

        it "is used" do
          expect(subject.safe_identifier).to eq("com.apple.project")
        end
      end

      context "when no value in project is given" do
        before { subject.identifier(nil) }

        it "is interpreted" do
          expect(subject.safe_identifier).to eq("test.chefsoftware.pkg.project-full-name")
        end
      end

      context 'when interpolated values are "unsafe"' do
        before do
          project.name("$Project123.for-realz_2")
          project.maintainer("This is SPARTA!")
          subject.identifier(nil)
        end

        it 'uses the "safe" values' do
          expect(subject.safe_identifier).to eq("test.thisissparta.pkg.project123forrealz2")
        end
      end
    end

    describe "#safe_build_iteration" do
      it "returns the build iternation" do
        expect(subject.safe_build_iteration).to eq(project.build_iteration)
      end
    end

    describe "#safe_version" do
      context 'when the project build_version is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_version).to eq("1.2.3")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project build_version has invalid characters" do
        before { project.build_version("1.2$alpha.##__2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2-alpha.-2")
          end

          expect(output).to include("The `version' component of Mac package names can only include")
        end
      end
    end

    describe "#find_linked_libs" do
      context "with linked libs" do
        let(:file) { "/opt/#{project.name}/embedded/bin/test_bin" }
        let(:stdout) do
          <<~EOH
            /opt/#{project.name}/embedded/bin/test_bin:
                      /opt/#{project.name}/embedded/lib/lib.dylib (compatibility version 7.0.0, current version 7.4.0)
                      /opt/#{project.name}/embedded/lib/lib.6.dylib (compatibility version 7.0.0, current version 7.4.0)
                      /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1281.0.0)
          EOH
        end
        let(:shellout) { Mixlib::ShellOut.new }

        before do
          allow(shellout).to receive(:run_command)
          allow(shellout).to receive(:stdout)
            .and_return(stdout)
          allow(subject).to receive(:shellout!)
            .with("otool -L #{file}")
            .and_return(shellout)
        end

        it "returns empty array" do
          expect(subject.find_linked_libs(file)).to eq([
            "/opt/#{project.name}/embedded/lib/lib.dylib",
            "/opt/#{project.name}/embedded/lib/lib.6.dylib",
          ])
        end
      end

      context "with only system linked libs" do
        let(:file) { "/opt/#{project.name}/embedded/lib/lib.dylib" }
        let(:stdout) do
          <<~EOH
            /opt/#{project.name}/embedded/lib/lib.dylib:
                      /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1281.0.0)
          EOH
        end
        let(:shellout) { Mixlib::ShellOut.new }
        before do
          allow(shellout).to receive(:run_command)
          allow(shellout).to receive(:stdout)
            .and_return(stdout)
          allow(subject).to receive(:shellout!)
            .with("otool -L #{file}")
            .and_return(shellout)
        end

        it "returns empty array" do
          expect(subject.find_linked_libs(file)).to eq([])
        end
      end

      context "file is just a file" do
        let(:file) { "/opt/#{project.name}/embedded/lib/file.rb" }
        let(:shellout) { Mixlib::ShellOut.new }
        before do
          allow(shellout).to receive(:run_command)
          allow(shellout).to receive(:stdout)
            .and_return("#{file}: is not an object file")
          allow(subject).to receive(:shellout!)
            .with("otool -L #{file}")
            .and_return(shellout)
        end

        it "returns empty array" do
          expect(subject.find_linked_libs(file)).to eq([])
        end
      end
    end

    describe "#is_binary?" do
      context "when is a file, executable, and not a symlink" do
        before do
          allow(File).to receive(:file?).with("file").and_return(true)
          allow(File).to receive(:executable?).with("file").and_return(true)
          allow(File).to receive(:symlink?).with("file").and_return(false)
        end

        it "returns true" do
          expect(subject.is_binary?("file")).to be true
        end
      end

      context "when not a file" do
        before do
          allow(File).to receive(:file?).with("file").and_return(false)
          allow(File).to receive(:executable?).with("file").and_return(true)
          allow(File).to receive(:symlink?).with("file").and_return(false)
        end

        it "returns false" do
          expect(subject.is_binary?("file")).to be false
        end
      end

      context "when not an executable" do
        it "returns false" do
          allow(File).to receive(:file?).with("file").and_return(true)
          allow(File).to receive(:executable?).with("file").and_return(false)
          allow(File).to receive(:symlink?).with("file").and_return(false)
          expect(subject.is_binary?("file")).to be false
        end
      end

      context "when is symlink" do
        it "returns false" do
          allow(File).to receive(:file?).with("file").and_return(true)
          allow(File).to receive(:executable?).with("file").and_return(true)
          allow(File).to receive(:symlink?).with("file").and_return(true)
          expect(subject.is_binary?("file")).to be false
        end
      end
    end

    describe "#is_macho?" do
      let(:shellout) { Mixlib::ShellOut.new }

      context "when is a Mach-O library" do
        before do
          allow(subject).to receive(:is_binary?).with("file").and_return(true)
          expect(subject).to receive(:shellout!).with("file file").and_return(shellout)
          allow(shellout).to receive(:stdout)
            .and_return("file: Mach-O 64-bit dynamically linked shared library x86_64")
        end

        it "returns true" do
          expect(subject.is_macho?("file")).to be true
        end
      end

      context "when is a Mach-O Bundle" do
        before do
          allow(subject).to receive(:is_binary?).with("file").and_return(true)
          expect(subject).to receive(:shellout!).with("file file").and_return(shellout)
          allow(shellout).to receive(:stdout)
            .and_return("file: Mach-O 64-bit bundle x86_64")
        end

        it "returns true" do
          expect(subject.is_macho?("file")).to be true
        end
      end

      context "when is not a Mach-O Bundle or Mach-O library" do
        before do
          allow(subject).to receive(:is_binary?).with("file").and_return(true)
          expect(subject).to receive(:shellout!).with("file file").and_return(shellout)
          allow(shellout).to receive(:stdout)
            .and_return("file: ASCII text")
        end

        it "returns true" do
          expect(subject.is_macho?("file")).to be false
        end
      end
    end

    describe "#sign_library" do
      before do
        subject.signing_identity("My Special Identity")
      end

      it "calls sign_binary without hardened runtime" do
        expect(subject).to receive(:sign_binary).with("file")
        subject.sign_library("file")
      end
    end

    describe "#sign_binary" do
      before do
        subject.signing_identity("My Special Identity")
      end

      it "it signs the binary without hardened runtime" do
        expect(subject).to receive(:shellout!)
          .with("codesign -s '#{subject.signing_identity}' 'file' --force\n")
        subject.sign_binary("file")
      end

      context "with hardened runtime" do
        it "it signs the binary with hardened runtime" do
          expect(subject).to receive(:shellout!)
            .with("codesign -s '#{subject.signing_identity}' 'file' --options=runtime --force\n")
          subject.sign_binary("file", true)
        end

        context "with entitlements" do
          let(:entitlements_file) { File.join(tmp_path, "project-full-name/resources/project-full-name/pkg/entitlements.plist") }

          it "it signs the binary with the entitlements" do
            allow(subject).to receive(:resource_path).with("entitlements.plist").and_return(entitlements_file)
            allow(File).to receive(:exist?).with(entitlements_file).and_return(true)
            expect(subject).to receive(:shellout!)
              .with("codesign -s '#{subject.signing_identity}' 'file' --options=runtime --entitlements #{entitlements_file} --force\n")
            subject.sign_binary("file", true)
          end
        end
      end
    end
  end
end
