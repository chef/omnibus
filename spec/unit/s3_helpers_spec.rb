require "spec_helper"
require "omnibus/s3_helpers"

module Omnibus
  describe S3Helpers do
    include Omnibus::S3Helpers

    context "when #s3_configuration is not defined" do
      describe "#client" do
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

    describe "#to_base64_digest" do
      it 'turns "c3b5247592ce694f7097873aa07d66fe" into "w7UkdZLOaU9wl4c6oH1m/g=="' do
        expect(to_base64_digest("c3b5247592ce694f7097873aa07d66fe")).to eql("w7UkdZLOaU9wl4c6oH1m/g==")
      end

      it "allows a nil input without error" do
        expect(to_base64_digest(nil)).to be_nil
      end
    end
  end

  context "when #s3_configuration is defined" do
    describe "#get_credentials" do
      let(:klass) do
        Class.new do
          include Omnibus::S3Helpers
        end
      end
      let(:instance) { klass.new }
      let(:key_pair) { { access_key_id: "key_id", secret_access_key: "access_key" } }
      let(:profile) { "my-profile" }
      let(:iam_role_arn) { "my-iam-role-arn" }
      let(:role_session_name) { "omnibus-assume-role-s3-access" }
      let(:config) { { bucket_name: "foo", region: "us-east-1" } }

      it "uses configured key pairs" do
        allow_any_instance_of(klass).to receive(:s3_configuration).and_return(config.merge!(key_pair))
        expect(Aws::Credentials).to receive(:new).with(
          config[:access_key_id],
          config[:secret_access_key]
        )
        expect(Aws::SharedCredentials).to_not receive(:new)
        instance.send(:get_credentials)
      end

      it "prefers shared credentials profiles over key pairs" do
        allow_any_instance_of(klass).to receive(:s3_configuration).and_return(
          {
            **config,
            **key_pair,
            iam_role_arn: nil,
            profile: profile,
          }
        )
        expect(Aws::Credentials).to_not receive(:new)
        expect(Aws::AssumeRoleCredentials).to_not receive(:new)
        allow(Aws::SharedCredentials).to receive(:new).with(profile_name: profile)
        instance.send(:get_credentials)
      end

      it "prefers AWS IAM role arn over profiles and key pairs" do
        allow_any_instance_of(klass).to receive(:s3_configuration).and_return(
          {
            **config,
            **key_pair,
            profile: profile,
            iam_role_arn: iam_role_arn,
          }
        )
        expect(Aws::Credentials).to_not receive(:new)
        expect(Aws::SharedCredentials).to_not receive(:new)
        allow(Aws::AssumeRoleCredentials).to receive(:new).with(role_arn: iam_role_arn, role_session_name: role_session_name)
        instance.send(:get_credentials)
      end

    end
  end
end
