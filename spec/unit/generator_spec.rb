require "spec_helper"

module Omnibus
  describe Generator do
    let(:generator_out) { StringIO.new }
    let(:generator_err) { StringIO.new }

    before do
      allow_any_instance_of(Thor::Shell::Basic).to receive(:stdout)
        .and_return(generator_out)
      allow_any_instance_of(Thor::Shell::Basic).to receive(:stdout)
        .and_return(generator_err)
    end

    let(:structure) do
      Dir.glob("#{tmp_path}/**/*", File::FNM_DOTMATCH)
        .sort
        .reject { |path| %w{. ..}.include?(File.basename(path)) }
        .map { |path| path.sub("#{tmp_path}/", "") }
    end

    context "with no arguments" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path).invoke_all

        expect(structure).to eq(%w{
          omnibus-name
          omnibus-name/.gitignore
          omnibus-name/.kitchen.local.yml
          omnibus-name/.kitchen.yml
          omnibus-name/Berksfile
          omnibus-name/Gemfile
          omnibus-name/README.md
          omnibus-name/config
          omnibus-name/config/projects
          omnibus-name/config/projects/name.rb
          omnibus-name/config/software
          omnibus-name/config/software/name-zlib.rb
          omnibus-name/omnibus.rb
          omnibus-name/package-scripts
          omnibus-name/package-scripts/name
          omnibus-name/package-scripts/name/postinst
          omnibus-name/package-scripts/name/postrm
          omnibus-name/package-scripts/name/preinst
          omnibus-name/package-scripts/name/prerm
        })
      end
    end

    context "with the --bff-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, bff_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/bff/gen.template.erb
        })
      end
    end

    context "with the --deb-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, deb_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/deb/conffiles.erb
          omnibus-name/resources/name/deb/control.erb
          omnibus-name/resources/name/deb/md5sums.erb
        })
      end
    end

    context "with the --dmg-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, dmg_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/dmg/background.png
          omnibus-name/resources/name/dmg/icon.png
        })
      end
    end

    context "with the --msi-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, msi_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/msi/assets/LICENSE.rtf
          omnibus-name/resources/name/msi/assets/banner_background.bmp
          omnibus-name/resources/name/msi/assets/dialog_background.bmp
          omnibus-name/resources/name/msi/assets/project.ico
          omnibus-name/resources/name/msi/assets/project_16x16.ico
          omnibus-name/resources/name/msi/assets/project_32x32.ico
          omnibus-name/resources/name/msi/localization-en-us.wxl.erb
          omnibus-name/resources/name/msi/parameters.wxi.erb
          omnibus-name/resources/name/msi/source.wxs.erb
        })
      end
    end

    context "with the --pkg-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, pkg_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/pkg/background.png
          omnibus-name/resources/name/pkg/license.html.erb
          omnibus-name/resources/name/pkg/welcome.html.erb
          omnibus-name/resources/name/pkg/distribution.xml.erb
        })
      end
    end

    context "with the --rpm-assets flag" do
      it "generates the proper file structure" do
        Generator.new(["name"], path: tmp_path, rpm_assets: true).invoke_all

        expect(structure).to include(*%w{
          omnibus-name/resources/name/rpm/rpmmacros.erb
          omnibus-name/resources/name/rpm/signing.erb
          omnibus-name/resources/name/rpm/spec.erb
        })
      end
    end
  end
end
