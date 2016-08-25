require "spec_helper"

module Omnibus
  describe Cleanroom do
    let(:klass) do
      Class.new do
        include Cleanroom

        def exposed_method
          @called = true
        end
        expose :exposed_method

        def unexposed_method; end
      end
    end

    let(:instance) { klass.new }

    describe "#evaluate" do
      it "exposes public methods" do
        expect do
          instance.evaluate("exposed_method")
        end.to_not raise_error
      end

      it "calls exposed methods on the instance" do
        instance.evaluate("exposed_method")
        expect(instance.instance_variable_get(:@called)).to be_truthy
      end

      it "does not expose unexposed methods" do
        expect do
          instance.evaluate("unexposed_method")
        end.to raise_error(NameError)
      end
    end

    describe "#evaluate_file" do
      let(:contents) do
        <<-EOH.gsub(/^ {10}/, "")
          exposed_method
        EOH
      end

      let(:filepath) { File.join(tmp_path, "/file/path") }

      before do
        allow(IO).to receive(:read).and_call_original
        allow(IO).to receive(:read).with(filepath).and_return(contents)
      end

      it "evaluates the file and exposes public methods" do
        expect { instance.evaluate_file(filepath) }.to_not raise_error
      end

      it "calls exposed methods on the instance" do
        instance.evaluate_file(filepath)
        expect(instance.instance_variable_get(:@called)).to be_truthy
      end
    end
  end
end
