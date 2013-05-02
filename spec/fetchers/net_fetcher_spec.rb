require 'spec_helper'

describe Omnibus::NetFetcher do
  it "should download and uncompress zip files" do
    software_mock = stub 'software'
    software_mock.stub :project_file => 'file.zip',
                       :name         => 'file',
                       :source       => '/tmp/out',
                       :checksum     => 'abc123',
                       :source_uri   => 'http://example.com/file.zip',
                       :source_dir   => '/tmp/out',
                       :project_dir  => '/tmp/project'
    net_fetcher = Omnibus::NetFetcher.new software_mock
    net_fetcher.extract_cmd.should == 'unzip file.zip -d /tmp/out'
  end
end
