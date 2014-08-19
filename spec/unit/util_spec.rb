require 'spec_helper'

module Omnibus
  describe Util do
    subject { Class.new { include Util }.new }

    describe '#create_directory' do
      before { allow(FileUtils).to receive(:mkdir_p) }

      it 'creates the directory' do
        expect(FileUtils).to receive(:mkdir_p).with('/foo/bar')
        subject.create_directory('/foo/bar')
      end

      it 'returns the path' do
        expect(subject.create_directory('/foo/bar')).to eq('/foo/bar')
      end

      it 'logs a message' do
        output = capture_logging { subject.create_directory('/foo/bar') }
        expect(output).to include("Creating directory `/foo/bar'")
      end
    end

    describe '#remove_directory' do
      before { allow(FileUtils).to receive(:rm_rf) }

      it 'remove the directory' do
        expect(FileUtils).to receive(:rm_rf).with('/foo/bar')
        subject.remove_directory('/foo/bar')
      end

      it 'accepts multiple parameters' do
        expect(FileUtils).to receive(:rm_rf).with('/foo/bar')
        subject.remove_directory('/foo', 'bar')
      end

      it 'logs a message' do
        output = capture_logging { subject.remove_directory('/foo/bar') }
        expect(output).to include("Remove directory `/foo/bar'")
      end
    end

    describe '#copy_file' do
      before { allow(FileUtils).to receive(:cp) }

      it 'copies the file' do
        expect(FileUtils).to receive(:cp).with('foo', 'bar')
        subject.copy_file('foo', 'bar')
      end

      it 'returns the destination path' do
        expect(subject.copy_file('foo', 'bar')).to eq('bar')
      end

      it 'logs a message' do
        output = capture_logging { subject.copy_file('foo', 'bar') }
        expect(output).to include("Copying `foo' to `bar'")
      end
    end

    describe '#remove_file' do
      before { allow(FileUtils).to receive(:rm_f) }

      it 'removes the file' do
        expect(FileUtils).to receive(:rm_f).with('/foo/bar')
        subject.remove_file('/foo/bar')
      end

      it 'accepts multiple parameters' do
        expect(FileUtils).to receive(:rm_f).with('/foo/bar')
        subject.remove_file('/foo', 'bar')
      end

      it 'logs a message' do
        output = capture_logging { subject.remove_file('/foo/bar') }
        expect(output).to include("Removing file `/foo/bar'")
      end
    end
  end
end
