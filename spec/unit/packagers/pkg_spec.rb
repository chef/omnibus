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

    describe '#id' do
      it "is :pkg" do
        expect(subject.id).to eq(:pkg)
      end
    end

    describe '#package_name' do
      it "includes the name, version, and build iteration" do
        expect(subject.package_name).to eq("project-full-name-1.2.3-2.pkg")
      end
    end

    describe '#resources_dir' do
      it "is nested inside the staging_dir" do
        expect(subject.resources_dir).to eq("#{staging_dir}/Resources")
      end
    end

    describe '#scripts_dir' do
      it "is nested inside the staging_dir" do
        expect(subject.scripts_dir).to eq("#{staging_dir}/Scripts")
      end
    end

    describe '#write_scripts' do
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

    describe '#build_component_pkg' do
      it "executes the pkgbuild command" do
        expect(subject).to receive(:shellout!).with <<-EOH.gsub(/^ {10}/, "")
          pkgbuild \\
            --identifier "com.getchef.project-full-name" \\
            --version "1.2.3" \\
            --scripts "#{staging_dir}/Scripts" \\
            --root "/opt/project-full-name" \\
            --install-location "/opt/project-full-name" \\
            "project-full-name-core.pkg"
        EOH

        subject.build_component_pkg
      end
    end

    describe '#write_distribution_file' do
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

    describe '#build_product_pkg' do
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
          project.name('$Project#')
        end

        it "uses com.example.PROJECT_NAME as the identifier" do
          expect(subject.safe_identifier).to eq("test.chefsoftware.pkg.project")
        end
      end
    end

    describe '#component_pkg' do
      it "returns the project name with -core.pkg" do
        expect(subject.component_pkg).to eq("project-full-name-core.pkg")
      end
    end

    describe '#safe_base_package_name' do
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

    describe '#safe_identifier' do
      context 'when Project#identifier is given' do
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

    describe '#safe_build_iteration' do
      it "returns the build iternation" do
        expect(subject.safe_build_iteration).to eq(project.build_iteration)
      end
    end

    describe '#safe_version' do
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
  end
end
