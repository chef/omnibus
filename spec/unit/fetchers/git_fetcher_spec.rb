require 'spec_helper'

module Omnibus
  describe GitFetcher do
    let(:software) do
      double(Software,
        name: 'project',
        source: { git: 'git@example.com:test/project.git' },
        version: '0.0.1',
        project_dir: '/tmp/project',
      )
    end

    subject { described_class.new(software) }

    describe '#fetch' do
      context 'when the project is cloned' do
        before do
          allow(subject).to receive(:existing_git_clone?).and_return(true)
          allow(subject).to receive(:fetch_updates)
        end

        context 'when the rev matches' do
          before { allow(subject).to receive(:current_rev_matches_target_rev?).and_return(true) }

          it 'does not fetch updates' do
            expect(subject).to_not receive(:fetch_updates)
            subject.fetch
          end
        end

        context 'when the rev does not match' do
          before { allow(subject).to receive(:current_rev_matches_target_rev?).and_return(false) }

          it 'fetches the updates' do
            expect(subject).to receive(:fetch_updates).once
            subject.fetch
          end
        end
      end

      context 'when the project is not cloned' do
        before do
          allow(subject).to receive(:existing_git_clone?).and_return(false)
          allow(subject).to receive(:clone)
          allow(subject).to receive(:checkout)
        end

        it 'clones the project' do
          expect(subject).to receive(:clone).once
          subject.fetch
        end

        it 'checkouts the ref' do
          expect(subject).to receive(:checkout).once
          subject.fetch
        end
      end

      context 'when something fails' do
        let(:error_reporter) { double(Fetcher::ErrorReporter, explain: nil) }

        before do
          allow(subject).to receive(:existing_git_clone?).and_return(false)
          allow(subject).to receive(:clone).and_raise(RuntimeError)

          allow(Fetcher::ErrorReporter).to receive(:new).and_return(error_reporter)
        end

        it 'retries 4 times' do
          allow(subject).to receive(:sleep)
          expect(subject).to receive(:clone).exactly(4).times
          expect { subject.fetch }.to raise_error(RuntimeError)
        end
      end
    end
  end
end
