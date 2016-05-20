require "stringio"

module Omnibus
  describe Compressor::Base do
    let(:packager) { double(Packager::Base) }
    let(:project)  { double(Project, packagers_for_system: [packager]) }

    describe ".initialize" do
      subject { described_class.new(project) }

      it "sets the project" do
        expect(subject.project).to eq(project)
      end

      it "sets the packager" do
        expect(subject.packager).to eq(packager)
      end
    end

    subject { described_class.new(project) }

    it "inherits from Packager" do
      expect(subject).to be_a(Packager::Base)
    end
  end
end
