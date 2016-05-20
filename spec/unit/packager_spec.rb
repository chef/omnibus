require "spec_helper"

module Omnibus
  describe Packager do
    describe ".for_current_system" do
      context "on Mac OS X" do
        before { stub_ohai(platform: "mac_os_x", version: "10.9.2") }
        it "prefers PKG" do
          expect(described_class.for_current_system).to eq([Packager::PKG])
        end
      end

      context "on Windows 2012" do
        before { stub_ohai(platform: "windows", version: "2012") }
        it "prefers MSI and APPX" do
          expect(described_class.for_current_system).to eq([Packager::MSI, Packager::APPX])
        end
      end

      context "on Windows 2008 R2" do
        before { stub_ohai(platform: "windows", version: "2008R2") }
        it "prefers MSI only" do
          expect(described_class.for_current_system).to eq([Packager::MSI])
        end
      end

      context "on Solaris 11" do
        before { stub_ohai(platform: "solaris2", version: "5.11") }
        it "prefers IPS" do
          expect(described_class.for_current_system).to eq([Packager::IPS])
        end
      end

      context "on Solaris 10" do
        before { stub_ohai(platform: "solaris2", version: "5.10") }
        it "prefers Solaris" do
          expect(described_class.for_current_system).to eq([Packager::Solaris])
        end
      end

      context "on aix" do
        before { stub_ohai(platform: "aix", version: "7.1") }
        it "prefers BFF" do
          expect(described_class.for_current_system).to eq([Packager::BFF])
        end
      end

      context "on fedora" do
        before { stub_ohai(platform: "fedora", version: "20") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::RPM])
        end
      end

      context "on debian" do
        before { stub_ohai(platform: "debian", version: "7.2") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::DEB])
        end
      end

      context "on suse" do
        before { stub_ohai(platform: "suse", version: "12.0") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::RPM])
        end
      end
    end
  end
end
