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

    it "is a sugarable" do
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
        expect do
          instance.evaluate <<-EOH.gsub(/^ {12}/, "")
            windows?
            vagrant?
          EOH
        end.to_not raise_error
      end
    end
  end

  describe Sugar do
    let(:klass) do
      Class.new do
        include Sugar
      end
    end

    let(:instance) { klass.new }

    it "returns the windows architecture being built" do
      expect(Omnibus::Config).to receive(:windows_arch).and_return(:x86_64)
      expect(instance.windows_arch_i386?).to eq(false)
    end

    it "returns whether fips_mode is enabled" do
      expect(Omnibus::Config).to receive(:fips_mode).and_return(false)
      expect(instance.fips_mode?).to eq(false)
    end
  end
end
