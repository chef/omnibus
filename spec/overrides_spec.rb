require 'omnibus/overrides'
require 'spec_helper'

describe Omnibus::Overrides do
  describe "#parse_file" do

    let(:overrides){Omnibus::Overrides.parse_file(file)}
    subject{overrides}

    context "with a valid overrides file" do
      let(:file){ overrides_path("good") }

      its(:size){should eq(5)}
      its(["foo"]){should eq("1.2.3")}
      its(["bar"]){should eq("0.0.1")}
      its(["baz"]){should eq("deadbeefdeadbeefdeadbeefdeadbeef")}
      its(["spunky"]){should eq("master")}
      its(["monkey"]){should eq("release")}
    end

    context "with an invalid overrides file" do
      let(:file){ overrides_path("invalid")}
      
      it "fails" do
        expect{ overrides }.to raise_error("Invalid overrides line: 'THIS IS A BAD LINE'")
      end
    end

  end
end
