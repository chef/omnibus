require "spec_helper"

module Omnibus
  describe Util do
    subject { Class.new { include Util }.new }

    describe "#retry_block" do
      class OurTestException < StandardError; end
      let(:expected_retries) { 3 }
      let(:expected_calls) { expected_retries + 1 }
      let(:sentinel) { double }

      it "retries the block if the passed exception is raised" do
        expect(sentinel).to receive(:call_me).and_raise(OurTestException)
        expect(sentinel).to receive(:call_me).and_return(:test_return)
        block_return = nil
        expect do
          block_return = subject.retry_block("test", [OurTestException], expected_retries) { sentinel.call_me }
        end.to_not raise_error
        expect(block_return).to eq(:test_return)
      end

      it "raises the last exception if the number of retries is exceeded" do
        expect(sentinel).to receive(:call_me).exactly(expected_calls).times.and_raise(OurTestException)
        expect do
          subject.retry_block("test", [OurTestException], expected_retries) { sentinel.call_me }
        end.to raise_error(OurTestException)
      end

      it "doesn't retry exceptions not listed by the user" do
        expect(sentinel).to receive(:call_me).exactly(1).times.and_raise(StandardError)
        expect do
          subject.retry_block("test", [OurTestException], expected_retries) { sentinel.call_me }
        end.to raise_error(StandardError)
      end
    end

    describe "#shellout!" do
      let(:shellout) do
        double(Mixlib::ShellOut,
          command:     "evil command",
          stdout:      "command failed",
          stderr:      "The quick brown fox did not jump over the barn!",
          timeout:     7_200,
          exitstatus:  32,
          environment: {
            "TICKLE_ME" => "elmo",
            "I_LOVE_YOU" => "barney",
          })
      end

      context "when the command fails" do
        before do
          allow(subject).to receive(:shellout)
            .and_return(shellout)
          allow(shellout).to receive(:error!)
            .and_raise(Mixlib::ShellOut::ShellCommandFailed)
        end

        it "raises an CommandFailed exception" do
          expect do
            subject.shellout!
          end.to raise_error(CommandFailed) { |error|
            message = error.message

            expect(message).to include("$ I_LOVE_YOU=barney TICKLE_ME=elmo evil command")
            expect(message).to include("command failed")
            expect(message).to include("The quick brown fox did not jump over the barn!")
          }
        end
      end

      context "when the command times out" do
        before do
          allow(subject).to receive(:shellout)
            .and_return(shellout)
          allow(shellout).to receive(:error!)
            .and_raise(Mixlib::ShellOut::CommandTimeout)
        end

        it "raises an CommandFailed exception" do
          expect do
            subject.shellout!
          end.to raise_error(CommandTimeout) { |error|
            message = error.message

            expect(message).to include("shell command timed out at 7,200 seconds")
            expect(message).to include("$ I_LOVE_YOU=barney TICKLE_ME=elmo evil command")
            expect(message).to include("Please increase the `:timeout' value")
          }
        end
      end
    end

    describe "#create_directory" do
      before { allow(FileUtils).to receive(:mkdir_p) }

      it "creates the directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/foo/bar")
        subject.create_directory("/foo/bar")
      end

      it "returns the path" do
        expect(subject.create_directory("/foo/bar")).to eq("/foo/bar")
      end

      it "logs a message" do
        output = capture_logging { subject.create_directory("/foo/bar") }
        expect(output).to include("Creating directory `/foo/bar'")
      end
    end

    describe "#remove_directory" do
      before { allow(FileUtils).to receive(:rm_rf) }

      it "remove the directory" do
        expect(FileUtils).to receive(:rm_rf).with("/foo/bar")
        subject.remove_directory("/foo/bar")
      end

      it "accepts multiple parameters" do
        expect(FileUtils).to receive(:rm_rf).with("/foo/bar")
        subject.remove_directory("/foo", "bar")
      end

      it "logs a message" do
        output = capture_logging { subject.remove_directory("/foo/bar") }
        expect(output).to include("Remove directory `/foo/bar'")
      end
    end

    describe "#copy_file" do
      before { allow(FileUtils).to receive(:cp) }

      it "copies the file" do
        expect(FileUtils).to receive(:cp).with("foo", "bar")
        subject.copy_file("foo", "bar")
      end

      it "returns the destination path" do
        expect(subject.copy_file("foo", "bar")).to eq("bar")
      end

      it "logs a message" do
        output = capture_logging { subject.copy_file("foo", "bar") }
        expect(output).to include("Copying `foo' to `bar'")
      end
    end

    describe "#remove_file" do
      before { allow(FileUtils).to receive(:rm_f) }

      it "removes the file" do
        expect(FileUtils).to receive(:rm_f).with("/foo/bar")
        subject.remove_file("/foo/bar")
      end

      it "accepts multiple parameters" do
        expect(FileUtils).to receive(:rm_f).with("/foo/bar")
        subject.remove_file("/foo", "bar")
      end

      it "logs a message" do
        output = capture_logging { subject.remove_file("/foo/bar") }
        expect(output).to include("Removing file `/foo/bar'")
      end
    end

    describe "#create_file" do
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:touch)
        allow(File).to receive(:open)
      end

      it "creates the containing directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/foo")
        subject.create_file("/foo/bar")
      end

      it "creates the file" do
        expect(FileUtils).to receive(:touch).with("/foo/bar")
        subject.create_file("/foo/bar")
      end

      it "accepts multiple parameters" do
        expect(FileUtils).to receive(:touch).with("/foo/bar")
        subject.create_file("/foo", "bar")
      end

      it "accepts a block" do
        expect(File).to receive(:open).with("/foo/bar", "wb")

        block = Proc.new { "Some content!" }
        subject.create_file("/foo", "bar", &block)
      end

      it "logs a message" do
        output = capture_logging { subject.create_file("/foo/bar") }
        expect(output).to include("Creating file `/foo/bar'")
      end
    end

    describe "#create_link" do
      before { allow(FileUtils).to receive(:ln_s) }

      it "creates the directory" do
        expect(FileUtils).to receive(:ln_s).with("/foo/bar", "/zip/zap")
        subject.create_link("/foo/bar", "/zip/zap")
      end

      it "logs a message" do
        output = capture_logging { subject.create_link("/foo/bar", "/zip/zap") }
        expect(output).to include("Linking `/foo/bar' to `/zip/zap'")
      end
    end
  end
end
