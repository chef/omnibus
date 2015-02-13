require 'spec_helper'
require 'omnibus/manifest_entry'

module Omnibus
  describe GitFetcher do
    include_examples 'a software'

    let(:remote)  { remote_git_repo('zlib') }
    let(:version) { 'master' }

    let(:source) do
      { git: remote }
    end

    subject { described_class.new(software) }

    describe '#fetch_required?' do
      context 'when the repo is not cloned' do
        it 'return true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context 'when the repo is cloned' do
        before { subject.fetch }

        context 'when the revisions are different' do
          it 'return true' do
            # Dirty the project_dir to differ the revisions
            Dir.chdir(project_dir) do
              FileUtils.touch("file-#{Time.now.to_i}")
              git %|add .|
              git %|commit -am "Add new file"|
            end

            expect(subject.fetch_required?).to be_truthy
          end
        end

        context 'when the revisions are the same' do
          it 'return false' do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      it 'includes the current revision' do
        expect(subject.version_guid).to match(/^git:[0-9a-f]{40}/)
      end
    end

    describe '#clean' do
      context 'when the project directory exists' do
        before do
          subject.fetch
          create_file("#{project_dir}/file_a")
          create_file("#{project_dir}/.file_b")
        end

        it 'cleans the git repo' do
          subject.clean
          expect("#{project_dir}/file_a").to_not be_a_file
          expect("#{project_dir}/.file_b").to_not be_a_file
        end

        it 'returns true' do
          expect(subject.clean).to be_truthy
        end
      end

      context 'when the project directory does not exist' do
        before do
          remove_directory(project_dir)
        end

        it 'returns false' do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#fetch'  do
      let(:revision) { shellout!('git rev-parse HEAD', cwd: project_dir).stdout.strip }

      it 'clones the repository' do
        subject.fetch
        expect("#{project_dir}/.git").to be_a_directory
      end

      context 'when the version is a tag' do
        let(:version)  { 'v1.2.3' }
        let(:remote)   { remote_git_repo('zlib', tags: [version]) }

        it 'parses the tag' do
          subject.fetch
          expect(revision).to eq('53c72c4abcc961b153996f5b5f402ce715e47146')
        end
      end

      context 'when the version is an annnotated tag' do
        let(:version)  { 'v1.2.4' }
        let(:remote)   { remote_git_repo('zlib', annotated_tags: [version]) }

        it 'it defererences and parses the annotated tag' do
          subject.fetch
          expect(revision).to eq('efde208366abd0f91419d8a54b45e3f6e0540105')
        end
      end

      context 'when the version is a branch' do
        let(:version) { 'sethvargo/magic_ponies' }
        let(:remote)  { remote_git_repo('zlib', branches: [version]) }

        it 'parses the branch' do
          subject.fetch
          expect(revision).to eq('171a1aec35ac0a050f8dccd9c9ef4609b1d8d8ea')
        end
      end

      context 'when the version is a full SHA-1' do
        let(:version) { '45ded6d3b1a35d66ed866b2c3eb418426e6382b0' }
        let(:remote)  { remote_git_repo('zlib') }

        it 'parses the full SHA-1' do
          subject.fetch
          expect(revision).to eq('45ded6d3b1a35d66ed866b2c3eb418426e6382b0')
        end
      end

      context 'when the version is a abbreviated SHA-1' do
        let(:version) { '45ded6d' }
        let(:remote)  { remote_git_repo('zlib') }

        it 'parses the abbreviated SHA-1' do
          subject.fetch
          expect(revision).to eq('45ded6d3b1a35d66ed866b2c3eb418426e6382b0')
        end
      end

      context 'when the version is a non-existent ref' do
        let(:version) { 'fufufufufu' }
        let(:remote)  { remote_git_repo('zlib') }

        it 'raise an exception' do
          expect { subject.fetch }.to raise_error(UnresolvableGitReference)
        end
      end

      context 'when a manifest entry locks a version' do
        let(:version)  { 'v1.2.4' }
        let(:remote)   { remote_git_repo('zlib', annotated_tags: [version]) }
        let (:a_manifest) {
          Omnibus::ManifestEntry.new("zlib",
                                     { :locked_version => 'efde208366abd0f91419d8a54b45e3f6e0540105',
                                       :locked_source => {:git => remote}})
        }

        it 'fetches the locked version' do
          subject.use_manifest_entry(a_manifest)
          subject.fetch
          expect(revision).to eq('efde208366abd0f91419d8a54b45e3f6e0540105')
        end
      end
    end

    describe '#version_for_cache' do
      let(:revision) { shellout!('git rev-parse HEAD', cwd: project_dir).stdout.strip }

      it 'includes the revision' do
        expect(subject.version_for_cache).to eq("revision:#{revision}")
      end

      it "does not returned cached revision after fetching" do
        before_fetch = subject.version_for_cache
        subject.fetch
        after_fetch = revision
        expect(subject.version_for_cache).to eq("revision:#{after_fetch}")
        expect(subject.version_for_cache).not_to eq("revision:#{before_fetch}")
      end
    end
  end
end
