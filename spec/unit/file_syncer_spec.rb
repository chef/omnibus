require "spec_helper"
require "omnibus/file_syncer"

module Omnibus
  describe FileSyncer do
    let(:fixture_dir) { "C:\\test" }

    describe "#glob", :windows_only do

      [ "/", "\\", "\\\\" ].each do |sep|
        it "should correctly clean the path with #{sep}" do
          pattern = fixture_dir + sep + "postinstall"
          expect(Dir).to receive(:glob).with("C:/test/postinstall", File::FNM_DOTMATCH).and_return(["C:/test/postinstall"])
          FileSyncer.glob(pattern)
        end
      end
    end
  end
end
