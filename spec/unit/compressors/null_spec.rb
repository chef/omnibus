require "spec_helper"

module Omnibus
  describe Compressor::Null do
    let(:packager) { double(Packager::Base) }
    let(:project)  { double(Project, packagers_for_system: [packager]) }

    subject { described_class.new(project) }

    describe '#id' do
      it "is :dmg" do
        expect(subject.id).to eq(:null)
      end
    end

    describe '#run!' do
      it "does nothing" do
        expect(subject).to_not receive(:instance_eval)
        subject.run!
      end
    end
  end
end
