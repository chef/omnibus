require "spec_helper"

module Omnibus
  describe Packager::Platform do
    describe '.create' do

      module Packager
        class DancePlatform < Platform
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

      it 'returns an instance of PlatformNamePlatform for recognized platforms' do
        instance = Packager::Platform.create({'platform_family' => 'fedora'})
         expect(instance).to be_a Packager::FedoraPlatform
      end
    end
  end

  describe Packager::DefaultPlatform do
    describe '.supported_packagers' do
      it 'returns Makeself' do
        platform_info = {'platform_family' => 'nonexistant', 'platform_version' => '0.1.1'}
        instance = Packager::DefaultPlatform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::Makeself])
      end
    end
  end

  describe Packager::Solaris2Platform do
    describe '.supported_packagers' do
      it 'returns solaris for 5.10.*' do
        platform_info = {'platform_family' => 'solaris2', 'platform_version' => '5.10.2'}
        instance = Packager::Solaris2Platform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::Solaris])
      end

      it 'returns ips for >=5.11' do
        platform_info = {'platform_family' => 'solaris2', 'platform_version' => '5.12'}
        instance = Packager::Solaris2Platform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::IPS])
      end

      it 'defaults to Makeself before 5.10' do
        platform_info = {'platform_family' => 'solaris2', 'platform_version' => '5.9'}
        instance = Packager::Solaris2Platform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::Makeself])
      end
    end
  end

  describe Packager::WindowsPlatform do
    describe '.supported_packagers' do
      it 'returns MSI for versions before 6.2' do
        platform_info = {'platform_family' => 'windows', 'platform_version' => '6.1'}
        instance = Packager::WindowsPlatform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::MSI])
      end

      it 'returns MSI and APPX for 6.2 and above' do
        platform_info = {'platform_family' => 'windows', 'platform_version' => '6.2.19'}
        instance = Packager::WindowsPlatform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::MSI, Packager::APPX])
      end
    end
  end

  describe Packager::DebianPlatform do
    describe '.supported_packagers' do
      it 'returns DEB' do
        platform_info = {'platform_family' => 'debian'}
        instance = Packager::DebianPlatform.new(platform_info)
        expect(instance.supported_packagers).to eq([Packager::DEB])
      end
    end
  end

  describe Packager::FedoraPlatform do
    describe '.supported_packagers' do
      it 'returns RPM' do
        instance = Packager::FedoraPlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::RPM])
      end
    end
  end

  describe Packager::SusePlatform do
    describe '.supported_packagers' do
      it 'returns RPM' do
        instance = Packager::SusePlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::RPM])
      end
    end
  end

  describe Packager::RhelPlatform do
    describe '.supported_packagers' do
      it 'returns RPM' do
        instance = Packager::RhelPlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::RPM])
      end
    end
  end

  describe Packager::WrlinuxPlatform do
    describe '.supported_packagers' do
      it 'returns RPM' do
        instance = Packager::WrlinuxPlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::RPM])
      end
    end
  end

  describe Packager::AixPlatform do
    describe '.supported_packagers' do
      it 'returns BFF' do
        instance = Packager::AixPlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::BFF])
      end
    end
  end

  describe Packager::Mac_os_xPlatform do
    describe '.supported_packagers' do
      it 'returns PKG' do
        instance = Packager::Mac_os_xPlatform.new({})
        expect(instance.supported_packagers).to eq([Packager::PKG])
      end
    end
  end

  describe Packager do
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
    end
  end
end
