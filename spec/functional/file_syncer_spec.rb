require 'spec_helper'

module Omnibus
  describe FileSyncer do
    describe '#glob' do
      before do
        FileUtils.mkdir_p(File.join(tmp_path, 'folder'))
        FileUtils.mkdir_p(File.join(tmp_path, '.hidden_folder'))

        FileUtils.touch(File.join(tmp_path, 'folder', 'file'))
        FileUtils.touch(File.join(tmp_path, '.hidden_file'))
      end

      let(:list) do
        described_class
          .glob("#{tmp_path}/**/*")
          .map { |item| item.sub("#{tmp_path}/", '') }
      end

      it 'includes regular files' do
        expect(list).to include('folder')
        expect(list).to include('folder/file')
      end

      it 'ignores .' do
        expect(list).to_not include('.')
      end

      it 'ignores ..' do
        expect(list).to_not include('..')
      end

      it 'includes hidden files' do
        expect(list).to include('.hidden_file')
      end

      it 'includes hidden folders' do
        expect(list).to include('.hidden_folder')
      end
    end

    describe '#sync' do
      let(:source) do
        source = File.join(tmp_path, 'source')
        FileUtils.mkdir_p(source)

        FileUtils.touch(File.join(source, 'file_a'))
        FileUtils.touch(File.join(source, 'file_b'))
        FileUtils.touch(File.join(source, 'file_c'))

        FileUtils.mkdir_p(File.join(source, 'folder'))
        FileUtils.touch(File.join(source, 'folder', 'file_d'))
        FileUtils.touch(File.join(source, 'folder', 'file_e'))

        FileUtils.mkdir_p(File.join(source, '.dot_folder'))
        FileUtils.touch(File.join(source, '.dot_folder', 'file_f'))

        FileUtils.touch(File.join(source, '.file_g'))
        source
      end

      let(:destination) { File.join(tmp_path, 'destination') }

      context 'when the destination is empty' do
        it 'syncs the directories' do
          described_class.sync(source, destination)

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file
        end
      end

      context 'when the directory exists' do
        before { FileUtils.mkdir_p(destination) }

        it 'deletes existing files and folders' do
          FileUtils.mkdir_p("#{destination}/existing_folder")
          FileUtils.mkdir_p("#{destination}/.existing_folder")
          FileUtils.touch("#{destination}/existing_file")
          FileUtils.touch("#{destination}/.existing_file")

          described_class.sync(source, destination)

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file

          expect("#{destination}/existing_folder").to_not be_a_directory
          expect("#{destination}/.existing_folder").to_not be_a_directory
          expect("#{destination}/existing_file").to_not be_a_file
          expect("#{destination}/.existing_file").to_not be_a_file
        end
      end

      context 'when :exclude is given' do
        it 'does not copy files and folders that match the pattern' do
          described_class.sync(source, destination, exclude: '.dot_folder')

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to_not be_a_directory
          expect("#{destination}/.dot_folder/file_f").to_not be_a_file
          expect("#{destination}/.file_g").to be_a_file
        end

        it 'removes existing files and folders in destination' do
          FileUtils.mkdir_p("#{destination}/existing_folder")
          FileUtils.touch("#{destination}/existing_file")
          FileUtils.mkdir_p("#{destination}/.dot_folder")
          FileUtils.touch("#{destination}/.dot_folder/file_f")

          described_class.sync(source, destination, exclude: '.dot_folder')

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to_not be_a_directory
          expect("#{destination}/.dot_folder/file_f").to_not be_a_file
          expect("#{destination}/.file_g").to be_a_file

          expect("#{destination}/existing_folder").to_not be_a_directory
          expect("#{destination}/existing_file").to_not be_a_file
        end
      end
    end
  end
end
