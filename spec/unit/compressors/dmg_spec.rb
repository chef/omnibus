require "spec_helper"

module Omnibus
  describe Compressor::DMG do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.friendly_name("Project One")
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
      allow(project).to receive(:packagers_for_system)
        .and_return([Packager::PKG.new(project)])

      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir)
        .and_return(staging_dir)
      create_directory(staging_dir)

      allow(subject).to receive(:shellout!)
    end

    describe '#window_bounds' do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:window_bounds)
      end

      it "has a default value" do
        expect(subject.window_bounds).to eq("100, 100, 750, 600")
      end
    end

    describe '#pkg_position' do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:pkg_position)
      end

      it "has a default value" do
        expect(subject.pkg_position).to eq("535, 50")
      end
    end

    describe '#id' do
      it "is :dmg" do
        expect(subject.id).to eq(:dmg)
      end
    end

    describe '#clean_disks' do
      it "logs a message" do
        allow(subject).to receive(:shellout!)
          .and_return(double(Mixlib::ShellOut, stdout: ""))

        output = capture_logging { subject.clean_disks }
        expect(output).to include("Cleaning previously mounted disks")
      end
    end

    describe "#create_volume_icon" do
      it "logs a message" do
        output = capture_logging { subject.create_volume_icon }
        expect(output).to include("Creating volume icon")
      end

      it "runs the sips commands" do
        icon = subject.resource_path("icon.png")

        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            # Generate the icns
            mkdir tmp.iconset
            sips -z 16 16     #{icon} --out tmp.iconset/icon_16x16.png
            sips -z 32 32     #{icon} --out tmp.iconset/icon_16x16@2x.png
            sips -z 32 32     #{icon} --out tmp.iconset/icon_32x32.png
            sips -z 64 64     #{icon} --out tmp.iconset/icon_32x32@2x.png
            sips -z 128 128   #{icon} --out tmp.iconset/icon_128x128.png
            sips -z 256 256   #{icon} --out tmp.iconset/icon_128x128@2x.png
            sips -z 256 256   #{icon} --out tmp.iconset/icon_256x256.png
            sips -z 512 512   #{icon} --out tmp.iconset/icon_256x256@2x.png
            sips -z 512 512   #{icon} --out tmp.iconset/icon_512x512.png
            sips -z 1024 1024 #{icon} --out tmp.iconset/icon_512x512@2x.png
            iconutil -c icns tmp.iconset
          EOH

        subject.create_volume_icon
      end
    end

    describe '#create_compressed_dmg' do
      it "logs a message" do
        output = capture_logging { subject.create_compressed_dmg }
        expect(output).to include("Creating compressed dmg")
      end

      it "runs the dmgbuild command" do
        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            pip install dmgbuild==1.6.5
            dmgbuild \\
              --detach-retries=5 \\
              --settings="#{subject.resource_path('settings.py')}" \\
              -Dbackground="#{subject.resource_path('background.png')}" \\
              -Dpkg="#{package_dir}/project-1.2.3-2.pkg" \\
              -Dpkg_position="535, 50" \\
              -Dvolume_icon="#{staging_dir}/tmp.icns" \\
              -Dwindow_bounds="100, 100, 750, 600" \\
              "Project One" \\
              "#{subject.package_path}"
          EOH

        subject.create_compressed_dmg
      end
    end

    describe "#verify_dmg" do
      it "logs a message" do
        output = capture_logging { subject.verify_dmg }
        expect(output).to include("Verifying dmg")
      end

      it "runs the command" do
        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            hdiutil verify \\
              "#{package_dir}/project-1.2.3-2.dmg" \\
              -puppetstrings
          EOH

        subject.verify_dmg
      end
    end

    describe "#set_dmg_icon" do
      it "logs a message" do
        output = capture_logging { subject.set_dmg_icon }
        expect(output).to include("Setting dmg icon")
      end

      it "runs the sips commands" do
        icon = subject.resource_path("icon.png")

        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            # Convert the png to an icon
            sips -i "#{icon}"

            # Extract the icon into its own resource
            DeRez -only icns "#{icon}" > tmp.rsrc

            # Append the icon reosurce to the DMG
            Rez -append tmp.rsrc -o "#{package_dir}/project-1.2.3-2.dmg"

            # Source the icon
            SetFile -a C "#{package_dir}/project-1.2.3-2.dmg"
          EOH

        subject.set_dmg_icon
      end
    end

    describe '#package_name' do
      it 'reflects the packager\'s unmodified package_name' do
        expect(subject.package_name).to eq("project-1.2.3-2.dmg")
      end

      it 'reflects the packager\'s modified package_name' do
        package_basename = "projectsub-1.2.3-3"
        allow(project.packagers_for_system[0]).to receive(:package_name)
          .and_return("#{package_basename}.pkg")

        expect(subject.package_name).to eq("#{package_basename}.dmg")
      end
    end

    describe '#volume_name' do
      it "is the project friendly_name" do
        expect(subject.volume_name).to eq("Project One")
      end
    end
  end
end
