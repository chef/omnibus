require "spec_helper"

module Omnibus
  describe Compressor::DMG do
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

    describe '#resources_dir' do
      it "is nested inside the staging_dir" do
        expect(subject.resources_dir).to eq("#{staging_dir}/Resources")
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

    describe '#create_writable_dmg' do
      it "logs a message" do
        output = capture_logging { subject.create_writable_dmg }
        expect(output).to include("Creating writable dmg")
      end

      it "runs the hdiutil command" do
        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            hdiutil create \\
              -srcfolder "#{staging_dir}/Resources" \\
              -volname "Project" \\
              -fs HFS+ \\
              -fsargs "-c c=64,a=16,e=16" \\
              -format UDRW \\
              -size 512000k \\
              "#{staging_dir}/project-writable.dmg"
          EOH

        subject.create_writable_dmg
      end
    end

    describe '#attach_dmg' do
      before do
        allow(subject).to receive(:shellout!)
          .and_return(shellout)
      end

      let(:shellout) { double(Mixlib::ShellOut, stdout: "hello\n") }

      it "logs a message" do
        output = capture_logging { subject.attach_dmg }
        expect(output).to include("Attaching dmg as disk")
      end

      it "runs the hdiutil command" do
        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            hdiutil attach \\
              -readwrite \\
              -noverify \\
              -noautoopen \\
              "#{staging_dir}/project-writable.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}'
          EOH

        subject.attach_dmg
      end

      it "returns the stripped stdout" do
        expect(subject.attach_dmg).to eq("hello")
      end
    end

    describe '#set_volume_icon' do
      it "logs a message" do
        output = capture_logging { subject.set_volume_icon }
        expect(output).to include("Setting volume icon")
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

            # Copy it over
            cp tmp.icns "/Volumes/Project/.VolumeIcon.icns"

            # Source the icon
            SetFile -a C "/Volumes/Project"
          EOH

        subject.set_volume_icon
      end
    end

    describe '#prettify_dmg' do
      it "logs a message" do
        output = capture_logging { subject.prettify_dmg }
        expect(output).to include("Making the dmg all pretty and stuff")
      end

      it "renders the apple script template" do
        subject.prettify_dmg
        expect("#{staging_dir}/create_dmg.osascript").to be_a_file
      end

      it "has the correct content" do
        subject.prettify_dmg
        contents = File.read("#{staging_dir}/create_dmg.osascript")

        expect(contents).to include('tell application "Finder"')
        expect(contents).to include('  tell disk "Project"')
        expect(contents).to include("    open")
        expect(contents).to include("    set current view of container window to icon view")
        expect(contents).to include("    set toolbar visible of container window to false")
        expect(contents).to include("    set statusbar visible of container window to false")
        expect(contents).to include("    set the bounds of container window to {100, 100, 750, 600}")
        expect(contents).to include("    set theViewOptions to the icon view options of container window")
        expect(contents).to include("    set arrangement of theViewOptions to not arranged")
        expect(contents).to include("    set icon size of theViewOptions to 72")
        expect(contents).to include('    set background picture of theViewOptions to file ".support:background.png"')
        expect(contents).to include("    delay 5")
        expect(contents).to include('    set position of item "project-1.2.3-2.pkg" of container window to {535, 50}')
        expect(contents).to include("    update without registering applications")
        expect(contents).to include("    delay 5")
        expect(contents).to include("  end tell")
        expect(contents).to include("end tell")
      end

      it "runs the apple script" do
        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            osascript "#{staging_dir}/create_dmg.osascript"
          EOH

        subject.prettify_dmg
      end
    end

    describe '#compress_dmg' do
      it "logs a message" do
        output = capture_logging { subject.compress_dmg }
        expect(output).to include("Compressing dmg")
      end

      it "runs the magical command series" do
        device = "/dev/sda1"
        subject.instance_variable_set(:@device, device)

        expect(subject).to receive(:shellout!)
          .with <<-EOH.gsub(/^ {12}/, "")
            chmod -Rf go-w /Volumes/Project
            sync
            hdiutil detach "#{device}"
            hdiutil convert \\
              "#{staging_dir}/project-writable.dmg" \\
              -format UDZO \\
              -imagekey \\
              zlib-level=9 \\
              -o "#{package_dir}/project-1.2.3-2.dmg"
            rm -rf "#{staging_dir}/project-writable.dmg"
          EOH

        subject.compress_dmg
      end
    end

    describe '#set_dmg_icon' do
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

    describe '#writable_dmg' do
      it "is in the staging_dir" do
        expect(subject.writable_dmg).to include(staging_dir)
      end

      it "is project-writable" do
        expect(subject.writable_dmg).to include("project-writable.dmg")
      end
    end

    describe '#volume_name' do
      it "is the project friendly_name" do
        project.friendly_name("Friendly Bacon Bits")
        expect(subject.volume_name).to eq("Friendly Bacon Bits")
      end
    end
  end
end
