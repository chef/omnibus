require 'spec_helper'

module Omnibus
  describe Packager::MSI do
    let(:project) do
      Project.new.tap do |project|
        project.name('project')
        project.homepage('https://example.com')
        project.install_dir('C:/project')
        project.build_version('1.2.3')
        project.build_iteration('2')
        project.maintainer('Chef Software <maintainers@chef.io>')
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, 'project/root') }
    let(:package_dir)  { File.join(tmp_path, 'package/dir') }
    let(:staging_dir)  { File.join(tmp_path, 'staging/dir') }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
    end

    describe 'DSL' do
      it 'exposes :parameters' do
        expect(subject).to have_exposed_method(:parameters)
      end

      it 'exposes :signing_identity' do
        expect(subject).to have_exposed_method(:signing_identity)
      end
    end

    describe '#id' do
      it 'is :pkg' do
        expect(subject.id).to eq(:msi)
      end
    end

    describe '#upgrade_code' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:upgrade_code)
      end

      it 'is required' do
        expect {
          subject.upgrade_code
        }.to raise_error(MissingRequiredAttribute)
      end

      it 'requires the value to be a String' do
        expect {
          subject.parameters(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        code = 'ABCD-1234'
        subject.upgrade_code(code)
        expect(subject.upgrade_code).to be(code)
      end
    end

    describe '#parameters' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:parameters)
      end

      it 'is defaults to an empty hash' do
        expect(subject.parameters).to be_a(Hash)
      end

      it 'requires the value to be a Hash' do
        expect {
          subject.parameters(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        params = { 'Key' => 'value' }
        subject.parameters(params)
        expect(subject.parameters).to be(params)
      end
    end

    describe '#package_name' do
      before do
        allow(Config).to receive(:windows_arch).and_return(:foo_arch)
      end

      it 'includes the name, version, and build iteration' do
        expect(subject.package_name).to eq('project-1.2.3-2-foo_arch.msi')
      end

      it 'returns the bundle name when building a bundle' do
        subject.bundle_msi(true)
        expect(subject.package_name).to eq('project-1.2.3-2-foo_arch.exe')
      end
    end

    describe '#resources_dir' do
      it 'is nested inside the staging_dir' do
        expect(subject.resources_dir).to eq("#{staging_dir}/Resources")
      end
    end

    describe '#write_localization_file' do
      it 'generates the file' do
        subject.write_localization_file
        expect("#{staging_dir}/localization-en-us.wxl").to be_a_file
      end

      it 'has the correct content' do
        subject.write_localization_file
        contents = File.read("#{staging_dir}/localization-en-us.wxl")

        expect(contents).to include('<String Id="ProductName">Project</String>')
        expect(contents).to include('<String Id="ManufacturerName">"Chef Software &lt;maintainers@chef.io&gt;"</String>')
        expect(contents).to include('<String Id="FeatureMainName">Project</String>')
      end
    end

    describe '#write_parameters_file' do
      before do
        subject.upgrade_code('ABCD-1234')
      end

      it 'generates the file' do
        subject.write_parameters_file
        expect("#{staging_dir}/parameters.wxi").to be_a_file
      end

      it 'has the correct content' do
        subject.write_parameters_file
        contents = File.read("#{staging_dir}/parameters.wxi")

        expect(contents).to include('<?define VersionNumber="1.2.3.2" ?>')
        expect(contents).to include('<?define DisplayVersionNumber="1.2.3" ?>')
        expect(contents).to include('<?define UpgradeCode="ABCD-1234" ?>')
      end
    end

    describe '#write_source_file' do
      it 'generates the file' do
        subject.write_source_file
        expect("#{staging_dir}/source.wxs").to be_a_file
      end

      it 'has the correct content' do
        project.install_dir('C:/foo/bar/blip')
        subject.write_source_file
        contents = File.read("#{staging_dir}/source.wxs")

        expect(contents).to include('<?include "parameters.wxi" ?>')
        expect(contents).to include <<-EOH.gsub(/^ {6}/, '')
          <Directory Id="TARGETDIR" Name="SourceDir">
            <Directory Id="WINDOWSVOLUME">
              <Directory Id="FOOLOCATION" Name="foo">
                <Directory Id="FOOBARLOCATION" Name="bar">
                  <Directory Id="PROJECTLOCATION" Name="blip">
                  </Directory>
                </Directory>
              </Directory>
            </Directory>
          </Directory>
        EOH
      end

      it 'has the correct wix_install_dir when the path is short' do
        subject.write_source_file
        contents = File.read("#{staging_dir}/source.wxs")

        expect(contents).to include('<?include "parameters.wxi" ?>')
        expect(contents).to include('<Property Id="WIXUI_INSTALLDIR" Value="WINDOWSVOLUME" />')
      end
    end

    describe '#write_bundle_file' do
      before do
        subject.bundle_msi(true)
        subject.upgrade_code('ABCD-1234')
        allow(Config).to receive(:windows_arch).and_return(:x86)
      end

      it 'generates the file' do
        subject.write_bundle_file
        expect("#{staging_dir}/bundle.wxs").to be_a_file
      end

      it 'has the correct content' do
        outpath = "#{tmp_path}/package/dir/project-1.2.3-2-x86.msi"
        outpath = outpath.gsub(File::SEPARATOR, File::ALT_SEPARATOR) if windows?
        subject.write_bundle_file
        contents = File.read("#{staging_dir}/bundle.wxs")
        expect(contents).to include("<MsiPackage SourceFile=\"#{outpath}\" EnableFeatureSelection=\"no\" />")
      end
    end

    describe '#msi_version' do
      context 'when the project build_version semver' do
        it 'returns the right value' do
          expect(subject.msi_version).to eq('1.2.3.2')
        end
      end

      context 'when the project build_version is git' do
        before { project.build_version('1.2.3-alpha.1+20140501194641.git.94.561b564') }

        it 'returns the right value' do
          expect(subject.msi_version).to eq('1.2.3.2')
        end
      end
    end

    describe '#msi_display_version' do
      context 'when the project build_version is "safe"' do
        it 'returns the right value' do
          expect(subject.msi_display_version).to eq('1.2.3')
        end
      end

      context 'when the project build_version is a git tag' do
        before { project.build_version('1.2.3-alpha.1+20140501194641.git.94.561b564') }

        it 'returns the right value' do
          expect(subject.msi_display_version).to eq('1.2.3')
        end
      end
    end

    describe '#wix_candle_extensions' do
      it 'defaults to an empty Array' do
        expect(subject.wix_candle_extensions).to be_an(Array)
        expect(subject.wix_candle_extensions).to be_empty
      end
    end

    describe '#wix_light_extensions' do
      it 'defaults to an empty Array' do
        expect(subject.wix_light_extensions).to be_an(Array)
        expect(subject.wix_light_extensions).to be_empty
      end
    end

    describe '#wix_candle_extension' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:wix_candle_extension)
      end

      it 'requires the value to be an String' do
        expect {
          subject.wix_candle_extension(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        extensions = ['a']
        subject.wix_candle_extension(extensions[0])
        expect(subject.wix_candle_extensions).to match_array(extensions)
      end
    end

    describe '#wix_light_extension' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:wix_light_extension)
      end

      it 'requires the value to be an String' do
        expect {
          subject.wix_light_extension(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        extensions = ['a']
        subject.wix_light_extension(extensions[0])
        expect(subject.wix_light_extensions).to match_array(extensions)
      end
    end

    describe '#wix_extension_switches' do
      it 'returns an empty string for an empty array' do
        expect(subject.wix_extension_switches([])).to eq('')
      end

      it 'returns the correct value for one extension' do
        expect(subject.wix_extension_switches(['a'])).to eq("-ext 'a'")
      end

      it 'returns the correct value for many extensions' do
        expect(subject.wix_extension_switches(['a', 'b'])).to eq("-ext 'a' -ext 'b'")
      end
    end

    describe "#bundle_msi" do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:bundle_msi)
      end

      it 'requires the value to be a TrueClass or a FalseClass' do
        expect {
          subject.bundle_msi(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        subject.bundle_msi(true)
        expect(subject.bundle_msi).to be_truthy
      end
    end

    context 'when signing parameters are provided' do
      let(:msi) { 'somemsi.msi' }

      context 'when invalid parameters' do
        it 'should raise an InvalidValue error when the certificate name is not a String' do
          expect{subject.signing_identity(Object.new)}.to raise_error(InvalidValue)
        end

        it 'should raise an InvalidValue error when params is not a Hash' do
          expect{subject.signing_identity("foo", Object.new)}.to raise_error(InvalidValue)
        end

        it 'should raise an InvalidValue error when params contains an invalid key' do
          expect{subject.signing_identity("foo", bar: 'baz')}.to raise_error(InvalidValue)
        end
      end

      context 'when valid parameters' do
        before do
          allow(subject).to receive(:shellout!)
        end

        it 'should sign the file and then add the timestamp' do
          subject.signing_identity('foo')
          expect(subject).to receive(:add_timestamp)
          subject.sign_package(msi)
        end

        describe "#timestamp_servers" do
          it "defaults to using ['http://timestamp.digicert.com','http://timestamp.verisign.com/scripts/timestamp.dll']" do
            subject.signing_identity('foo')
            expect(subject).to receive(:try_timestamp).with(msi, 'http://timestamp.digicert.com').and_return(false)
            expect(subject).to receive(:try_timestamp).with(msi, 'http://timestamp.verisign.com/scripts/timestamp.dll').and_return(true)
            subject.sign_package(msi)
          end

          it 'uses the timestamp server if provided through the #timestamp_server dsl' do
            subject.signing_identity('foo', timestamp_servers: 'http://fooserver')
            expect(subject).to receive(:try_timestamp).with(msi, 'http://fooserver').and_return(true)
            subject.sign_package(msi)
          end

          it 'tries all timestamp server if provided through the #timestamp_server dsl' do
            subject.signing_identity('foo', timestamp_servers: ['http://fooserver', 'http://barserver'])
            expect(subject).to receive(:try_timestamp).with(msi, 'http://fooserver').and_return(false)
            expect(subject).to receive(:try_timestamp).with(msi, 'http://barserver').and_return(true)
            subject.sign_package(msi)
          end

          it 'tries all timestamp server if provided through the #timestamp_servers dsl and stops at the first available' do
            subject.signing_identity('foo', timestamp_servers: ['http://fooserver', 'http://barserver'])
            expect(subject).to receive(:try_timestamp).with(msi, 'http://fooserver').and_return(true)
            expect(subject).not_to receive(:try_timestamp).with(msi, 'http://barserver')
            subject.sign_package(msi)
          end

          it 'raises an exception if there are no available timestamp servers' do
            subject.signing_identity('foo', timestamp_servers: 'http://fooserver')
            expect(subject).to receive(:try_timestamp).with(msi, 'http://fooserver').and_return(false)
            expect {subject.sign_package(msi)}.to raise_error(FailedToTimestampMSI)
          end
        end
      end
    end
  end
end
