require 'spec_helper'

describe Omnibus::GitFetcher do
  let(:shell_out) {
    shell_out = double('Mixlib::ShellOut')
    stub_const('Mixlib::ShellOut', shell_out)
    shell_out
  }
  let(:software) {
    double('software').tap { |s|
      s.stub :name => 'project',
             :source => { :git => 'git@example.com:test/project.git' },
             :version => '0.0.1',
             :project_dir => '/tmp/project'
    }
  }
  def expect_git_clone_and_ls_remote
    expect_git_clone
    expect_git_ls_remote
  end
  def expect_git_clone
    double('git_clone').tap do |g|
      shell_out.should_receive(:new)
        .with('git clone git@example.com:test/project.git /tmp/project', :live_stream => STDOUT)
        .ordered
        .and_return(g)
      g.should_receive(:run_command).ordered
      g.should_receive(:error!).ordered
    end
  end
  def expect_git_ls_remote
    double('git_ls_remote').tap do |g|
      shell_out.should_receive(:new)
        .with('git ls-remote origin 0.0.1*', :live_stream => STDOUT, :cwd => '/tmp/project')
        .ordered
        .and_return(g)
      g.should_receive(:run_command).ordered
      g.should_receive(:error!).ordered
      g.stub(:stdout => git_ls_remote_out)
    end
  end
  describe "#fetch" do
    context "when the project is not cloned yet" do
      before {
        File.stub(:exist?).with('/tmp/project/.git').and_return(false)
      }
      context "when the source repository is accessible" do
        subject {
          Omnibus::GitFetcher.new software
        }
        context "when the ref exists" do
          let(:git_ls_remote_out) {
            'a2ed66c01f42514bcab77fd628149eccb4ecee28	refs/tags/0.0.1'
          }
          it 'should clone the Git repository and then check out the commit' do
            1.times { expect_git_clone_and_ls_remote }
            double('git_checkout').tap do |g|
              shell_out.should_receive(:new)
                .with('git checkout a2ed66c01f42514bcab77fd628149eccb4ecee28', :live_stream => STDOUT, :cwd => '/tmp/project')
                .ordered
                .and_return(g)
              g.should_receive(:run_command).ordered
              g.should_receive(:error!).ordered
            end

            expect { subject.fetch }.to_not raise_error
          end
        end
        context "when the ref does not exist" do
          let(:git_ls_remote_out) {
            ''
          }
          it 'should clone the Git repository and then fail while retrying 3 times' do
             4.times {
               expect_git_clone
               4.times {
                 expect_git_ls_remote
               }
             }
            Omnibus::Fetcher::ErrorReporter.any_instance
              .should_receive(:explain).with(%q|Failed to fetch git repository 'git@example.com:test/project.git'|)
            subject.should_receive(:log).with(%r|git ls-remote failed|).at_least(1).times
            subject.should_receive(:log).with(%r|git clone/fetch failed|).at_least(1).times
            # Prevent sleeping to run the spec fast
            subject.stub(:sleep)
            expect { subject.fetch }.to raise_error(/Could not parse SHA reference/)
          end
        end
      end
    end
  end
end

