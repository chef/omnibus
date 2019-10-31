require "spec_helper"

module Omnibus
  describe Compressor do
    describe ".for_current_system" do
      context "on Mac OS X" do
        before { stub_ohai(platform: "mac_os_x", version: "10.12") }

        context "when :dmg is activated" do
          it "prefers dmg" do
            expect(described_class.for_current_system(%i{tgz dmg})).to eq(Compressor::DMG)
          end
        end

        context "when :dmg is not activated" do
          it "prefers tgz" do
            expect(described_class.for_current_system(%i{tgz foo})).to eq(Compressor::TGZ)
          end
        end

        context "when nothing is given" do
          it "returns null" do
            expect(described_class.for_current_system([])).to eq(Compressor::Null)
          end
        end
      end

      context "on Ubuntu" do
        before { stub_ohai(platform: "ubuntu", version: "16.04") }

        context "when :tgz activated" do
          it "prefers tgz" do
            expect(described_class.for_current_system(%i{tgz foo})).to eq(Compressor::TGZ)
          end
        end

        context "when nothing is given" do
          it "returns null" do
            expect(described_class.for_current_system([])).to eq(Compressor::Null)
          end
        end
      end
    end
  end
end
