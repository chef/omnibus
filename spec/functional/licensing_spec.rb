require "spec_helper"

module Omnibus
  describe Licensing do
    let(:license) { nil }
    let(:license_file_path) { nil }
    let(:license_file) { nil }

    let(:install_dir) { File.join(tmp_path, "install_dir")}
    let(:software_project_dir) { File.join(tmp_path, "software_project_dir")}

    before do
      FileUtils.mkdir_p(install_dir)
      FileUtils.mkdir_p(software_project_dir)
      allow_any_instance_of(Software).to receive(:project_dir).and_return(software_project_dir)
      %w{README LICENSE NOTICE}.each do |file|
        File.open(File.join(software_project_dir, file), "w+") do |f|
          f.puts "This file is #{file}."
        end
      end
    end

    shared_examples "correctly created licenses" do
      it "creates the main license file for the project correctly" do
        project_license = File.join(install_dir, expected_project_license_path)
        expect(File.exist?(project_license)).to be(true)
        project_license = File.read(project_license)
        expect(project_license).to match /test-project 1.2.3 license: "#{expected_project_license}"/
        expect(project_license).to match /#{expected_project_license_content}/
        expect(project_license).to match /This product bundles private_code 1.7.2,\nwhich is available under a "Unspecified"/
        expect(project_license).to match /This product bundles snoopy 1.0.0,\nwhich is available under a "GPL v2"/
        expect(project_license).to match /This product bundles zlib 1.7.2,\nwhich is available under a "Zlib"/
        expect(project_license).not_to match /preparation/
        expect(project_license).to match /LICENSES\/snoopy-README/
        expect(project_license).to match /LICENSES\/snoopy-NOTICE/
        expect(project_license).to match /LICENSES\/zlib-LICENSE/
      end

      it "creates the license files of software components correctly" do
        license_dir = File.join(install_dir, "LICENSES")
        expect(Dir.glob("#{license_dir}/**/*").length).to be(3)

        %w{snoopy-NOTICE snoopy-README zlib-LICENSE}.each do |software_license|
          license_path = File.join(license_dir, software_license)
          expect(File.exist?(license_path)).to be(true)
          expect(File.read(license_path)).to match /#{software_license.split("-").last}/
        end
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
        license_file "README"
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

    def create_licenses
      project.library.component_added(preparation)
      project.library.component_added(snoopy)
      project.library.component_added(zlib)
      project.library.component_added(private_code)

      Licensing.create!(project)
    end

    describe "without license definitions in the project" do
      let(:expected_project_license_path) { "LICENSE" }
      let(:expected_project_license) { "Unspecified" }
      let(:expected_project_license_content) { "" }

      before do
        create_licenses
      end

      it_behaves_like "correctly created licenses"
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

        create_licenses
      end

      after do
        FileUtils.rm_rf(license_file)
      end

      it_behaves_like "correctly created licenses"
    end
  end
end
