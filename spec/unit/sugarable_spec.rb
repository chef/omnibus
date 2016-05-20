require "spec_helper"

module Omnibus
  describe Software do
    it "is a sugarable" do
      expect(described_class.ancestors).to include(Sugarable)
    end
  end

  describe Metadata do
    it "extends Sugarable" do
      expect(described_class.singleton_class.included_modules).to include(Sugarable)
    end

    it "includes Sugarable" do
      expect(described_class.ancestors).to include(Sugarable)
    end
  end

  describe Packager::Base do
    it "is a sugarable" do
      expect(described_class.ancestors).to include(Sugarable)
    end
  end

  describe Project do
    it "is a sugarable" do
      expect(described_class.ancestors).to include(Sugarable)
    end
  end

  describe Sugarable do
    context "in a cleanroom" do
      let(:klass) do
        Class.new do
          include Cleanroom
          include Sugarable
        end
      end

      let(:instance) { klass.new }

      it "includes the DSL methods" do
        expect(klass).to be_method_defined(:windows?)
        expect(klass).to be_method_defined(:vagrant?)
        expect(klass).to be_method_defined(:_64_bit?)
      end

      it "makes the DSL methods available in the cleanroom" do
        expect {
          instance.evaluate <<-EOH.gsub(/^ {12}/, "")
            windows?
            vagrant?
          EOH
        }.to_not raise_error
      end
    end
  end
end
