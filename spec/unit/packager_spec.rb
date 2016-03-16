require 'spec_helper'

module Omnibus
  describe Packager do
    context 'for Solaris 5.11' do
      before { stub_ohai(platform: 'solaris', platform_version: '5.11') }

      it "should activate IPS packager" do
        expect(described_class.for_current_system).to eq(:IPS)
      end
    end

    context 'for Solaris 5.10' do
      before { stub_ohai(platform: 'solaris', platform_version: '5.10') }

      it "should activate Solaris packager" do
        expect(described_class.for_current_system).to eq(:Solaris)
      end
    end
  end
end
