require "spec_helper"

module Omnibus
  describe Packager::Platform do
    describe '.create' do

      module Packager
        class DancePlatform
        end
      end

      it 'returns a class instance based on platform type' do
        instance = Packager::Platform.create({'platform_family' => 'dance'})
        expect(instance).to be_a Packager::DancePlatform
      end

      it 'returns an instance of DefaultPlatform for unrecognized platforms' do
        instance = Packager::Platform.create({'platform_family' => 'nonexistant'})
        expect(instance).to be_a Packager::DefaultPlatform
      end
    end
  end

 # describe Packager::DefaultPlatform do
 #   describe '.supported_packagers' do
 #     it 'returns Makeself' do
 #       instance = Packager::DefaultPlatform.new('nonexistant', '0.1.1')
 #       expect(instance.suppored_package_types).to eq([Makeself])
 #     end
 #   end
 # end

  describe Packager do
    describe ".for_current_system" do
      context "on Mac OS X" do
        before { stub_ohai(platform: "mac_os_x", version: "10.9.2") }
        it "prefers PKG" do
          expect(described_class.for_current_system).to eq([Packager::PKG])
        end
    describe '.for_current_system' do
      it 'delegates to Platform' do
        package_type_instance = double("package_type_instance")
        supported_packager = ['the polka']
        expect(Packager::Platform).to receive(:create).with(Ohai).
            and_return(package_type_instance)
        expect(package_type_instance).to receive(:supported_packagers).
            and_return(supported_packager)
        expect(described_class.for_current_system).to eq(supported_packager)
      end

  #    context 'on Mac OS X' do
  #      before { stub_ohai(platform: 'mac_os_x', version: '10.9.2') }
  #      it 'prefers PKG' do
  #          expect(described_class.for_current_system).to eq([Packager::PKG])
  #        end
  #    end

  #    context 'on Windows 2012' do
  #      before { stub_ohai(platform: 'windows', version: '2012') }
  #        it 'prefers MSI and APPX' do
  #          expect(described_class.for_current_system).to eq([Packager::MSI, Packager::APPX])
  #        end
  #    end

  #    context 'on Windows 2008 R2' do
  #      before { stub_ohai(platform: 'windows', version: '2008R2') }
  #        it 'prefers MSI only' do
  #          expect(described_class.for_current_system).to eq([Packager::MSI])
  #        end
  #    end

  #    context 'on Solaris 11' do
  #      before { stub_ohai(platform: 'solaris2', version: '5.11') }
  #        it 'prefers IPS' do
  #          expect(described_class.for_current_system).to eq([Packager::IPS])
  #        end
  #    end

  #    context 'on Solaris 10' do
  #      before { stub_ohai(platform: 'solaris2', version: '5.10') }
  #        it 'prefers Solaris' do
  #          expect(described_class.for_current_system).to eq([Packager::Solaris])
  #        end
  #    end


  #    context 'on aix' do
  #      before { stub_ohai(platform: 'aix', version: '7.1') }
  #        it 'prefers BFF' do
  #          expect(described_class.for_current_system).to eq([Packager::BFF])
  #        end
  #    end

  #    context 'on fedora' do
  #      before { stub_ohai(platform: 'fedora', version: '20') }
  #        it 'prefers RPM' do
  #          expect(described_class.for_current_system).to eq([Packager::RPM])
  #        end
  #    end

  #    context 'on debian' do
  #      before { stub_ohai(platform: 'debian', version: '7.2') }
  #        it 'prefers RPM' do
  #          expect(described_class.for_current_system).to eq([Packager::DEB])
  #        end
  #    end

  #    context 'on suse' do
  #      before { stub_ohai(platform: 'suse', version: '12.0') }
  #        it 'prefers RPM' do
  #          expect(described_class.for_current_system).to eq([Packager::RPM])
  #        end
  #    end
    end
  end
end
