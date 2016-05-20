require "spec_helper"
require "omnibus/s3_helpers"

module Omnibus
  describe S3Helpers do
    include Omnibus::S3Helpers

    context 'when #s3_configuration is not defined' do
      describe '#client' do
        it "raises an error if it is not overridden" do
          expect { s3_configuration }.to raise_error(RuntimeError,
                                                     "You must override s3_configuration")
        end

        it "raises an error stating that s3_configuration must be overriden" do
          expect { client }.to raise_error(RuntimeError,
                                           "You must override s3_configuration")
        end
      end
    end

    describe '#to_base64_digest' do
      it 'turns "c3b5247592ce694f7097873aa07d66fe" into "w7UkdZLOaU9wl4c6oH1m/g=="' do
        expect(to_base64_digest("c3b5247592ce694f7097873aa07d66fe")).to eql("w7UkdZLOaU9wl4c6oH1m/g==")
      end

      it "allows a nil input without error" do
        expect(to_base64_digest(nil)).to be_nil
      end
    end
  end
end
