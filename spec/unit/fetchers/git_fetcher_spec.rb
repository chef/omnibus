require 'spec_helper'

module Omnibus
  describe GitFetcher do
    let(:source_path) { '/local/path' }
    let(:project_dir) { '/project/dir' }

    let(:software) do
      double(Software,
        name: 'software',
        source: { path: source_path },
        project_dir: project_dir,
      )
    end

    subject { described_class.new(software) }

    describe '#fetch_required?' do
      context 'when the repository is not cloned' do
        before { allow(subject).to receive(:cloned?).and_return(false) }

        it 'returns true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context 'when the repository is cloned' do
        before { allow(subject).to receive(:cloned?).and_return(true) }

        context 'when the revision is difference' do
          before { allow(subject).to receive(:same_revision?).and_return(false) }

          it 'returns true' do
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context 'when the same revision is checked out'  do
          before { allow(subject).to receive(:same_revision?).and_return(true) }

          it 'returns false' do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      let(:revision) { 'abcd1234' }

      before do
        allow(subject).to receive(:current_revision).and_return(revision)
      end

      it 'returns the revision' do
        expect(subject.version_guid).to eq("git:#{revision}")
      end
    end

    describe '#clean' do
      before { allow(subject).to receive(:git) }

      context 'when the repository is cloned' do
        before do
          allow(subject).to receive(:cloned?).and_return(true)
        end

        it 'gleans the directory' do
          expect(subject).to receive(:git).with('clean -fdx')
          subject.clean
        end

        it 'returns true' do
          expect(subject.clean).to be_truthy
        end
      end

      context 'when the repository is not cloned' do
        before do
          allow(subject).to receive(:cloned?).and_return(false)
        end

        it 'does not clean the repository' do
          expect(subject).to_not receive(:git)
          subject.clean
        end

        it 'returns false' do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#fetch' do
      before do
        allow(subject).to receive(:create_required_directories)
        allow(subject).to receive(:git_fetch)
        allow(subject).to receive(:git_clone)
        allow(subject).to receive(:git_checkout)
      end

      context 'when the repository is cloned' do
        before { allow(subject).to receive(:cloned?).and_return(true) }

        context 'when the revision is different' do
          before { allow(subject).to receive(:same_revision?).and_return(false) }

          it 'fetches and resets' do
            expect(subject).to receive(:git_fetch)
            subject.fetch
          end
        end

        context 'when the revision is the same' do
          before { allow(subject).to receive(:same_revision?).and_return(true) }

          it 'does not fetch or reset' do
            expect(subject).to_not receive(:git_fetch)
            subject.fetch
          end
        end
      end

      context 'when the repository is not cloned' do
        before { allow(subject).to receive(:cloned?).and_return(false) }

        it 'clones the repository' do
          expect(subject).to receive(:git_clone).once
          subject.fetch
        end

        it 'checks out the correct revision' do
          expect(subject).to receive(:git_checkout).once
          subject.fetch
        end
      end
    end

    describe '#version_for_cache' do
      let(:revision) { 'abcd1234' }

      before { allow(subject).to receive(:current_revision).and_return(revision) }

      it 'returns the shasum of the project_dir' do
        expect(subject.version_for_cache).to eq("revision:#{revision}")
      end
    end
  end
end
