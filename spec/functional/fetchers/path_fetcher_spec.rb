require 'spec_helper'

module Omnibus
  describe PathFetcher do
    include_examples 'a software'

    let(:source_path) { File.join(tmp_path, 'remote', 'software') }

    let(:source) do
      { path: source_path }
    end

    before do
      create_directory(source_path)
    end

    subject { described_class.new(software) }

    describe '#fetch_required?' do
      context 'when the directories have different files' do
        before do
          create_file("#{source_path}/directory/file") { 'different' }
          create_file("#{project_dir}/directory/file") { 'same' }
        end

        it 'return true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context 'when the directories have the same files' do
        before do
          create_file("#{source_path}/directory/file") { 'same' }
          create_file("#{project_dir}/directory/file") { 'same' }
        end

        it 'returns false' do
          expect(subject.fetch_required?).to be_falsey
        end
      end
    end

    describe '#version_guid' do
      it 'includes the source path' do
        expect(subject.version_guid).to eq("path:#{source_path}")
      end
    end

    describe '#clean' do
      context 'when the project directory exists' do
        before do
          create_file("#{source_path}/file_a")
          create_file("#{source_path}/file_b")
          create_file("#{source_path}/.file_c")

          create_file("#{project_dir}/file_a")
        end

        it 'fetches new files' do
          subject.clean

          expect("#{project_dir}/file_a").to be_a_file
          expect("#{project_dir}/file_b").to be_a_file
          expect("#{project_dir}/.file_c").to be_a_file
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
          expect(subject.clean).to be_falsey
        end
      end
    end

    describe '#version_for_cache' do
      before do
        create_file("#{project_dir}/file_a")
        create_file("#{project_dir}/file_b")
        create_file("#{project_dir}/.file_c")
      end

      let(:sha) { '69553b23b84e69e095b4a231877b38022b1ffb41ae0ecbba6bb2625410c49f7e' }

      it 'includes the source_path and shasum' do
        expect(subject.version_for_cache).to eq("path:#{source_path}|shasum:#{sha}")
      end
    end
  end
end
