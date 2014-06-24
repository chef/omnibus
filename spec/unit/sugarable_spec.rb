require 'spec_helper'

module Omnibus
  describe Software do
    it 'is a sugarable' do
      expect(subject).to be_a(Sugarable)
    end
  end

  describe Project do
    it 'is a sugarable' do
      expect(subject).to be_a(Sugarable)
    end
  end

  describe Sugarable do
    context 'in a cleanroom' do
      let(:klass) do
        Class.new do
          include Cleanroom
          include Sugarable
        end
      end

      let(:instance) { klass.new }

      before { stub_ohai(platform: 'ubuntu') }

      it 'includes the DSL methods' do
        expect(klass).to be_method_defined(:windows?)
        expect(klass).to be_method_defined(:vagrant?)
        expect(klass).to be_method_defined(:_64_bit?)
      end

      it 'makes the DSL methods available in the cleanroom' do
        expect {
          instance.evaluate <<-EOH.gsub(/^ {12}/, '')
            windows?
            vagrant?
          EOH
        }.to_not raise_error
      end
    end
  end
end
