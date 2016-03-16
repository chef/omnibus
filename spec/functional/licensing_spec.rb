require "spec_helper"

module Omnibus
  describe Licensing do
    let(:license) { nil }
    let(:license_file_path) { nil }
    let(:license_file) { nil }

    let(:install_dir) { File.join(tmp_path, "install_dir")}
    let(:software_project_dir) { File.join(tmp_path, "software_project_dir")}

    let(:expected_project_license_path) { "LICENSE" }
    let(:expected_project_license) { "Unspecified" }
    let(:expected_project_license_content) { "" }

    before do
      FileUtils.mkdir_p(install_dir)
      FileUtils.mkdir_p(software_project_dir)

      allow_any_instance_of(Software).to receive(:project_dir).and_return(software_project_dir)
      %w{LICENSE NOTICE}.each do |file|
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
        expect(project_license).to match /This product bundles zlib 1.7.2,\nwhich is available under a "Zlib"/
        expect(project_license).not_to match /preparation/
        expect(project_license).to match /LICENSES\/snoopy-artistic.html/
        expect(project_license).to match /LICENSES\/snoopy-NOTICE/
        expect(project_license).to match /LICENSES\/zlib-LICENSE/
      end

      it "creates the license files of software components correctly" do
        create_licenses
        license_dir = File.join(install_dir, "LICENSES")
        expect(Dir.glob("#{license_dir}/**/*").length).to be(3)

        %w{snoopy-NOTICE zlib-LICENSE}.each do |software_license|
          license_path = File.join(license_dir, software_license)
          expect(File.exist?(license_path)).to be(true)
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
        project.name('test-project')
        project.install_dir(install_dir)
        project.license(license) unless license.nil?
        project.license_file_path(license_file_path) unless license_file_path.nil?
        project.license_file(license_file) unless license_file.nil?
        project.build_version('1.2.3')
      end
    end

    let(:private_code) do
      Software.new(project, 'private_code.rb').evaluate do
        name 'private_code'
        default_version '1.7.2'
      end
    end

    let(:zlib) do
      Software.new(project, 'zlib.rb').evaluate do
        name 'zlib'
        default_version '1.7.2'
        license "Zlib"
        license_file "LICENSE"
      end
    end

    let(:snoopy) do
      Software.new(project, 'snoopy.rb').evaluate do
        name 'snoopy'
        default_version '1.0.0'
        license "GPL v2"
        license_file "http://dev.perl.org/licenses/artistic.html"
        license_file "NOTICE"
      end
    end

    let(:preparation) do
      Software.new(project, 'preparation.rb').evaluate do
        name 'preparation'
        default_version '1.0.0'
        license :project_license
      end
    end

    let(:software_with_warnings) { nil }

    def create_licenses
      project.library.component_added(preparation)
      project.library.component_added(snoopy)
      project.library.component_added(zlib)
      project.library.component_added(private_code)
      project.library.component_added(software_with_warnings) if software_with_warnings

      Licensing.create!(project)
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
    end

    describe "with a local license file that does not exist" do
      let(:software_with_warnings) do
        Software.new(project, 'problematic.rb').evaluate do
          name 'problematic'
          default_version '0.10.2'
          license_file "NOT_EXISTS"
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
        Software.new(project, 'problematic.rb').evaluate do
          name 'problematic'
          default_version '0.10.2'
          license_file "https://downloads.chef.io/LICENSE"
        end
      end

      it_behaves_like "correctly created licenses"

      it "should log a warning for the missing file" do
        output = capture_logging { create_licenses }
        expect(output).to match(/Retrying failed download/)
        expect(output).to match(/Can not download license file 'https:\/\/downloads.chef.io\/LICENSE' for software 'problematic'./)
      end
    end

    describe "with a software with no license files" do
      let(:software_with_warnings) do
        Software.new(project, 'problematic.rb').evaluate do
          name 'problematic'
          default_version '0.10.2'
          license "Zlib"
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
  end
end
