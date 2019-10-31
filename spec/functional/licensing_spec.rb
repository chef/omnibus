require "spec_helper"

module Omnibus
  describe Licensing do
    let(:license) { nil }
    let(:license_file_path) { nil }
    let(:license_file) { nil }
    let(:zlib_version_override) { nil }

    let(:install_dir) { File.join(tmp_path, "install_dir") }
    let(:software_project_dir) { File.join(tmp_path, "software_project_dir") }

    let(:expected_project_license_path) { "LICENSE" }
    let(:expected_project_license) { "Unspecified" }
    let(:expected_project_license_content) { "" }

    before do
      FileUtils.mkdir_p(install_dir)
      FileUtils.mkdir_p(software_project_dir)

      allow_any_instance_of(Software).to receive(:project_dir).and_return(software_project_dir)
      %w{LICENSE NOTICE APACHE}.each do |file|
        File.open(File.join(software_project_dir, file), "w+") do |f|
          f.puts "This file is #{file}."
        end
      end
    end

    shared_examples "correctly created licenses" do
      it "creates the main license file for the project correctly" do
        create_licenses
        project_license = File.join(install_dir, expected_project_license_path)
        expect(File.exist?(project_license)).to be(true)
        project_license = File.read(project_license)
        expect(project_license).to match /test-project 1.2.3 license: "#{expected_project_license}"/
        expect(project_license).to match /#{expected_project_license_content}/
        expect(project_license).to match /This product bundles private_code 1.7.2,\nwhich is available under a "Unspecified"/
        expect(project_license).to match /This product bundles snoopy 1.0.0,\nwhich is available under a "GPL v2"/
        expect(project_license).not_to match /preparation/
        expect(project_license).to match %r{LICENSES/snoopy-artistic.html}
        expect(project_license).to match %r{LICENSES/snoopy-NOTICE}
        if zlib_version_override
          expect(project_license).to match /This product bundles zlib 1.8.0,\nwhich is available under a "Apache-2.0"/
          expect(project_license).to match %r{LICENSES/zlib-APACHE}
        else
          expect(project_license).to match /This product bundles zlib 1.7.2,\nwhich is available under a "Zlib"/
          expect(project_license).to match %r{LICENSES/zlib-LICENSE}
        end
      end

      it "creates the license files of software components correctly" do
        create_licenses
        license_dir = File.join(install_dir, "LICENSES")
        expect(Dir.glob("#{license_dir}/**/*").length).to be(3)

        license_names = [ "snoopy-NOTICE" ]
        if zlib_version_override
          license_names << "zlib-APACHE"
        else
          license_names << "zlib-LICENSE"
        end

        license_names.each do |software_license|
          license_path = File.join(license_dir, software_license)
          expect(File.exist?(license_path)).to be(true)
          expect(File.world_readable?(license_path)).to be_truthy
          expect(File.read(license_path)).to match /#{software_license.split("-").last}/
        end

        remote_license_file = File.join(license_dir, "snoopy-artistic.html")
        remote_license_file_contents = File.read(remote_license_file)
        expect(File.exist?(remote_license_file)).to be(true)
        expect(remote_license_file_contents).to match /The "Artistic License" - dev.perl.org/
      end

      it "warns for non-standard software license info" do
        output = capture_logging { create_licenses }
        expect(output).to include("Software 'snoopy' uses license 'GPL v2' which is not one of the standard licenses")
      end

      it "warns for missing software license info" do
        output = capture_logging { create_licenses }
        expect(output).to include("Software 'private_code' does not contain licensing information.")
      end
    end

    let(:project) do
      Project.new.tap do |project|
        project.name("test-project")
        project.install_dir(install_dir)
        project.license(license) unless license.nil?
        project.license_file_path(license_file_path) unless license_file_path.nil?
        project.license_file(license_file) unless license_file.nil?
        project.build_version("1.2.3")
        if zlib_version_override
          project.override :zlib, version: zlib_version_override
        end
      end
    end

    let(:private_code) do
      Software.new(project, "private_code.rb").evaluate do
        name "private_code"
        default_version "1.7.2"
        skip_transitive_dependency_licensing true
      end
    end

    let(:zlib) do
      Software.new(project, "zlib.rb").evaluate do
        name "zlib"
        default_version "1.7.2"
        skip_transitive_dependency_licensing true

        license "Zlib"
        license_file "LICENSE"

        version "1.8.0" do
          license "Apache-2.0"
          license_file "APACHE"
        end
      end
    end

    let(:snoopy) do
      Software.new(project, "snoopy.rb").evaluate do
        name "snoopy"
        default_version "1.0.0"
        skip_transitive_dependency_licensing true

        license "GPL v2"
        license_file "http://dev.perl.org/licenses/artistic.html"
        license_file "NOTICE"
      end
    end

    let(:preparation) do
      Software.new(project, "preparation.rb").evaluate do
        name "preparation"
        default_version "1.0.0"
        license :project_license
        skip_transitive_dependency_licensing true
      end
    end

    let(:software_with_warnings) { nil }

    let(:softwares) do
      s = [preparation, snoopy, zlib, private_code]
      s << software_with_warnings if software_with_warnings
      s
    end

    def create_licenses
      softwares.each { |s| project.library.component_added(s) }

      Licensing.create_incrementally(project) do |licensing|
        yield licensing if block_given?

        project.softwares.each do |software|
          licensing.execute_post_build(software)
        end
      end
    end

    describe "prepare step" do

      let(:licenses_dir) { File.join(install_dir, "LICENSES") }
      let(:dot_gitkeep) { File.join(licenses_dir, ".gitkeep") }
      let(:cache_dir) { File.join(install_dir, "license-cache") }
      let(:cache_dot_gitkeep) { File.join(cache_dir, ".gitkeep") }

      it "creates a LICENSES dir with a .gitkeep file inside the install directory" do
        Licensing.new(project).prepare
        expect(File).to exist(licenses_dir)
        expect(File).to exist(dot_gitkeep)
      end

      it "creates a licenses-cache dir with a .gitkeep file inside the install directory" do
        Licensing.new(project).prepare
        expect(File).to exist(cache_dir)
        expect(File).to exist(cache_dot_gitkeep)
      end

    end

    describe "without license definitions in the project" do
      it_behaves_like "correctly created licenses"

      it "warns for missing project license" do
        output = capture_logging { create_licenses }
        expect(output).to include("Project 'test-project' does not contain licensing information.")
      end
    end

    describe "with license definitions in the project" do
      let(:license) { "Custom Chef" }
      let(:license_file_path) { "CHEF.LICENSE" }
      let(:license_file) { "CUSTOM_CHEF" }

      let(:expected_project_license_path) { license_file_path }
      let(:expected_project_license) { license }
      let(:expected_project_license_content) { "Chef Custom License" }

      before do
        File.open(File.join(Config.project_root, license_file), "w+") do |f|
          f.puts "Chef Custom License is awesome."
        end
      end

      after do
        FileUtils.rm_rf(license_file)
      end

      it_behaves_like "correctly created licenses"

      it "warns for non-standard project license" do
        output = capture_logging { create_licenses }
        expect(output).to include("Project 'test-project' is using 'Custom Chef' which is not one of the standard licenses")
      end

      context "with a version override" do
        let(:zlib_version_override) { "1.8.0" }

        it_behaves_like "correctly created licenses"
      end
    end

    describe "with a local license file that does not exist" do
      let(:software_with_warnings) do
        Software.new(project, "problematic.rb").evaluate do
          name "problematic"
          default_version "0.10.2"
          license_file "NOT_EXISTS"
          skip_transitive_dependency_licensing true
        end
      end

      it_behaves_like "correctly created licenses"

      it "should log a warning for the missing file" do
        output = capture_logging { create_licenses }
        expect(output).to match /License file (.*)NOT_EXISTS' does not exist for software 'problematic'./
      end
    end

    describe "with a remote license file that does not exist" do
      before do
        Omnibus::Config.fetcher_retries(1)
      end

      let(:software_with_warnings) do
        Software.new(project, "problematic.rb").evaluate do
          name "problematic"
          default_version "0.10.2"
          license_file "https://downloads.chef.io/LICENSE"
          skip_transitive_dependency_licensing true
        end
      end

      it_behaves_like "correctly created licenses"

      it "should log a warning for the missing file" do
        output = capture_logging { create_licenses }
        expect(output).to match(/Retrying failed download/)
        expect(output).to match(%r{Can not download license file 'https://downloads.chef.io/LICENSE' for software 'problematic'.})
      end
    end

    describe "with a software with no license files" do
      let(:software_with_warnings) do
        Software.new(project, "problematic.rb").evaluate do
          name "problematic"
          default_version "0.10.2"
          license "Zlib"
          skip_transitive_dependency_licensing true
        end
      end

      it_behaves_like "correctly created licenses"

      it "should log a warning for the missing file pointers" do
        output = capture_logging { create_licenses }
        expect(output).to include("Software 'problematic' does not point to any license files.")
      end
    end

    describe "with a project with no license files" do
      let(:license) { "Zlib" }

      let(:expected_project_license_path) { "LICENSE" }
      let(:expected_project_license) { license }
      let(:expected_project_license_content) { "" }

      it_behaves_like "correctly created licenses"

      it "warns for missing license files" do
        output = capture_logging { create_licenses }
        expect(output).to include("Project 'test-project' does not point to a license file.")
      end
    end

    describe "with :fatal_licensing_warnings set and without license definitions in the project" do
      before do
        Omnibus::Config.fatal_licensing_warnings(true)
      end

      it "fails the omnibus build" do
        expect { create_licenses }.to raise_error(Omnibus::LicensingError, /Project 'test-project' does not contain licensing information.\s{1,}Software 'private_code' does not contain licensing information./)
      end
    end

    describe "when all software is setting skip_transitive_dependency_licensing " do
      # This is achieved by the default values of the let() parameters

      it "does not collect transitive licensing info for any software" do
        softwares.each { |s| project.library.component_added(s) }
        create_licenses do |licensing|
          expect(licensing).not_to receive(:collect_transitive_dependency_licenses_for)
        end
      end
    end

    describe "when a project has transitive dependencies" do
      let(:license) { "Custom Chef" }
      let(:license_file_path) { "CHEF.LICENSE" }
      let(:license_file) { "CUSTOM_CHEF" }

      let(:expected_project_license_path) { license_file_path }

      let(:softwares) { [zlib] }

      before do
        File.open(File.join(Config.project_root, license_file), "w+") do |f|
          f.puts "Chef Custom License is awesome."
        end
      end

      after do
        FileUtils.rm_rf(license_file)
      end

      let(:zlib) do
        Software.new(project, "zlib.rb").evaluate do
          name "zlib"
          default_version "1.7.2"

          license "Zlib"
          license_file "LICENSE"
        end
      end

      let(:snoopy) do
        Software.new(project, "snoopy.rb").evaluate do
          name "snoopy"
          default_version "1.0.0"

          license "GPL v2"
          license_file "NOTICE"
        end
      end

      let(:license_fixtures_path) { File.join(fixtures_path, "licensing/license_scout") }

      describe "when project type is not supported" do

        before do
          allow_any_instance_of(LicenseScout::Collector).to receive(:run) do
            raise LicenseScout::Exceptions::UnsupportedProjectType.new("/path/to/project")
          end
        end

        it "does not raise an error" do
          expect { create_licenses }.not_to raise_error
        end

        it "logs a warning message" do
          output = capture_logging { create_licenses }
          expect(output).to include("is not supported project type for transitive dependency license collection")
        end

        context "with :fatal_licensing_warnings" do

          before do
            Omnibus::Config.fatal_licensing_warnings(true)
          end

          it "does not fail omnibus build" do
            expect { create_licenses }.not_to raise_error
          end
        end

        context "with :fatal_transitive_dependency_licensing_warnings" do

          before do
            Omnibus::Config.fatal_transitive_dependency_licensing_warnings(true)
          end

          it "fails omnibus build" do
            expect { create_licenses }.to raise_error(Omnibus::LicensingError, /is not supported project type for transitive dependency license collection/)
          end
        end
      end

      describe "when there are warnings in the licensing info" do
        before do
          allow_any_instance_of(LicenseScout::Collector).to receive(:run) do
            FileUtils.cp_r(File.join(license_fixtures_path, "zlib"), File.join(install_dir, "license-cache/"))
          end
          allow_any_instance_of(LicenseScout::Reporter).to receive(:report).and_return(["This is a licensing warning!!!"])
        end

        it "logs the warnings" do
          output = capture_logging { create_licenses }
          expect(output).to include("This is a licensing warning!!!")
        end

        describe "when :fatal_transitive_dependency_licensing_warnings is set" do
          before do
            Omnibus::Config.fatal_transitive_dependency_licensing_warnings(true)
          end

          it "raises an error after post_build step" do
            expect do
              create_licenses do |licensing|
                expect(licensing).not_to receive(:process_transitive_dependency_licensing_info)
              end
            end.to raise_error(Omnibus::LicensingError)
          end
        end
      end

      describe "when there are no warnings in the licensing info" do
        before do
          allow_any_instance_of(LicenseScout::Collector).to receive(:run) do
            FileUtils.cp_r(File.join(license_fixtures_path, "zlib"), File.join(install_dir, "license-cache/"))
          end

          allow_any_instance_of(LicenseScout::Collector).to receive(:issue_report).and_return([])
        end

        let(:expected_license_files) do
          %w{
            ruby_bundler-inifile-3.0.0-README.md
            ruby_bundler-mime-types-3.1-Licence.rdoc
            ruby_bundler-mini_portile2-2.1.0-LICENSE.txt
          }
        end

        let(:expected_license_texts) do
          [
            <<~EOH,
              This product includes inifile 3.0.0
              which is a 'ruby_bundler' dependency of 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-inifile-3.0.0-README.md
            EOH
            <<~EOH,
              This product includes mime-types 3.1
              which is a 'ruby_bundler' dependency of 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-mime-types-3.1-Licence.rdoc
            EOH
            <<~EOH,
              This product includes mini_portile2 2.1.0
              which is a 'ruby_bundler' dependency of 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-mini_portile2-2.1.0-LICENSE.txt
            EOH
          ]
        end

        it "includes transitive dependency license information in the project license information" do
          create_licenses

          project_license = File.join(install_dir, expected_project_license_path)
          expect(File.exist?(project_license)).to be(true)
          project_license_content = File.read(project_license)

          expected_license_texts.each { |t| expect(project_license_content).to include(t) }
          expected_license_files.each { |f| expect(File).to exist(File.join(install_dir, "LICENSES", f)) }
          expect(File).not_to exist(File.join(install_dir, "license-cache"))
        end
      end

      describe "with multiple softwares that have dependencies" do
        let(:softwares) { [zlib, snoopy] }

        before do
          allow_any_instance_of(LicenseScout::Collector).to receive(:run) do
            FileUtils.cp_r(File.join(license_fixtures_path, "zlib"), File.join(install_dir, "license-cache/"))
            FileUtils.cp_r(File.join(license_fixtures_path, "snoopy"), File.join(install_dir, "license-cache/"))
          end

          allow_any_instance_of(LicenseScout::Collector).to receive(:issue_report).and_return([])
        end

        let(:expected_license_files) do
          %w{
            ruby_bundler-inifile-3.0.0-README.md
            ruby_bundler-mime-types-3.1-Licence.rdoc
            ruby_bundler-mini_portile2-2.1.0-LICENSE.txt
          }
        end

        let(:expected_license_texts) do
          [
            <<~EOH,
              This product includes inifile 3.0.0
              which is a 'ruby_bundler' dependency of 'snoopy', 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-inifile-3.0.0-README.md
            EOH
            <<~EOH,
              This product includes mime-types 3.1
              which is a 'ruby_bundler' dependency of 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-mime-types-3.1-Licence.rdoc
            EOH
            <<~EOH,
              This product includes mini_portile2 2.1.0
              which is a 'ruby_bundler' dependency of 'zlib',
              and which is available under a 'MIT' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-mini_portile2-2.1.0-LICENSE.txt
            EOH
            <<~EOH,
              This product includes bundler-audit 0.5.0
              which is a 'ruby_bundler' dependency of 'snoopy',
              and which is available under a 'GPLv3' License.
              For details, see:
              #{install_dir}/LICENSES/ruby_bundler-bundler-audit-0.5.0-COPYING.txt
            EOH

          ]
        end

        it "includes merged licensing information from multiple software definitions" do
          create_licenses

          project_license = File.join(install_dir, expected_project_license_path)
          expect(File.exist?(project_license)).to be(true)
          project_license_content = File.read(project_license)

          expected_license_texts.each { |t| expect(project_license_content).to include(t) }
          expected_license_files.each { |f| expect(File).to exist(File.join(install_dir, "LICENSES", f)) }
          expect(File).not_to exist(File.join(install_dir, "license-cache"))
        end

      end

    end
  end
end
