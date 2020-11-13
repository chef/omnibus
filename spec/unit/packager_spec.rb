require "spec_helper"

module Omnibus
  describe Packager do
    describe ".for_current_system" do
      context "on Mac OS X" do
        before { stub_ohai(platform: "mac_os_x", version: "10.15") }
        it "prefers PKG" do
          expect(described_class.for_current_system).to eq([Packager::PKG])
        end
      end

      context "on Windows 2012 R2" do
        before { stub_ohai(platform: "windows", version: "2012R2") }
        it "prefers MSI and APPX" do
          expect(described_class.for_current_system).to eq([Packager::MSI, Packager::APPX, Packager::InstallBuilder])
        end
      end

      context "on Windows 2008 R2" do
        before { stub_ohai(platform: "windows", version: "2008R2") }
        it "prefers MSI only" do
          expect(described_class.for_current_system).to eq([Packager::MSI, Packager::InstallBuilder])
        end
      end

      context "on Solaris 11" do
        before { stub_ohai(platform: "solaris2", version: "5.11") }
        it "prefers IPS" do
          expect(described_class.for_current_system).to eq([Packager::IPS])
        end
      end

      context "on AIX" do
        before { stub_ohai(platform: "aix", version: "7") }
        it "prefers BFF" do
          expect(described_class.for_current_system).to eq([Packager::BFF])
        end
      end

      context "on Fedora" do
        before { stub_ohai(platform: "fedora", version: "31") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::RPM])
        end
      end

      context "on Amazon Linux 2" do
        before { stub_ohai(platform: "amazon", version: "2") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::RPM])
        end
      end

      context "on Debian" do
        before { stub_ohai(platform: "debian", version: "10") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::DEB])
        end
      end

      context "on SLES" do
        before { stub_ohai(platform: "suse", version: "15") }
        it "prefers RPM" do
          expect(described_class.for_current_system).to eq([Packager::RPM])
        end
      end
    end
  end
end
