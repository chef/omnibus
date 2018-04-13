require "spec_helper"

module Omnibus
  describe FileSyncer do
    describe "#glob" do
      before do
        FileUtils.mkdir_p(File.join(tmp_path, "folder"))
        FileUtils.mkdir_p(File.join(tmp_path, ".hidden_folder"))

        FileUtils.touch(File.join(tmp_path, "folder", "file"))
        FileUtils.touch(File.join(tmp_path, ".hidden_file"))
      end

      let(:list) do
        described_class
          .glob("#{tmp_path}/**/*")
          .map { |item| item.sub("#{tmp_path}/", "") }
      end

      it "includes regular files" do
        expect(list).to include("folder")
        expect(list).to include("folder/file")
      end

      it "ignores ." do
        expect(list).to_not include(".")
      end

      it "ignores .." do
        expect(list).to_not include("..")
      end

      it "includes hidden files" do
        expect(list).to include(".hidden_file")
      end

      it "includes hidden folders" do
        expect(list).to include(".hidden_folder")
      end
    end

    describe "#sync" do
      let(:source) do
        source = File.join(tmp_path, "source")
        FileUtils.mkdir_p(source)

        FileUtils.touch(File.join(source, "file_a"))
        FileUtils.touch(File.join(source, "file_b"))
        FileUtils.touch(File.join(source, "file_c"))

        FileUtils.mkdir_p(File.join(source, "folder"))
        FileUtils.touch(File.join(source, "folder", "file_d"))
        FileUtils.touch(File.join(source, "folder", "file_e"))

        FileUtils.mkdir_p(File.join(source, ".dot_folder"))
        FileUtils.touch(File.join(source, ".dot_folder", "file_f"))

        FileUtils.touch(File.join(source, ".file_g"))

        FileUtils.mkdir_p(File.join(source, "nested", "deep", "folder"))
        FileUtils.touch(File.join(source, "nested", "deep", "folder", "file_h"))
        FileUtils.touch(File.join(source, "nested", "deep", "folder", "file_i"))

        FileUtils.mkdir_p(File.join(source, "nested", "deep", "deep", "folder"))
        FileUtils.touch(File.join(source, "nested", "deep", "deep", "folder", "file_j"))
        FileUtils.touch(File.join(source, "nested", "deep", "deep", "folder", "file_k"))
        source
      end

      let(:destination) { File.join(tmp_path, "destination") }

      context "when the destination is empty" do
        it "syncs the directories" do
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

      context "when destination file exists" do

        let(:source) do
          s = File.join(tmp_path, "source")
          FileUtils.mkdir_p(s)
          p = create_file(s, "read-only-file") { "new" }
          FileUtils.chmod(0400, p)
          s
        end

        let(:destination) do
          dest = File.join(tmp_path, "destination")
          FileUtils.mkdir_p(dest)
          create_file(dest, "read-only-file") { "old" }
          FileUtils.chmod(0400, File.join(dest, "read-only-file"))
          dest
        end

        it "copies over a read-only file" do
          described_class.sync(source, destination)
          expect("#{destination}/read-only-file").to have_content "new"
        end
      end

      context "when the directory exists" do
        before { FileUtils.mkdir_p(destination) }

        it "deletes existing files and folders" do
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

      context "when target files are hard links" do
        let(:source) do
          source = File.join(tmp_path, "source")
          FileUtils.mkdir_p(source)

          create_directory(source, "bin")
          create_file(source, "bin", "git")
          FileUtils.ln("#{source}/bin/git", "#{source}/bin/git-tag")
          FileUtils.ln("#{source}/bin/git", "#{source}/bin/git-write-tree")

          source
        end

        it "copies the first instance and links to that instance thereafter" do
          FileUtils.mkdir_p("#{destination}/bin")

          described_class.sync(source, destination)

          expect("#{destination}/bin/git").to be_a_file
          if windows?
            expect("#{destination}/bin/git-tag").to be_a_file
            expect("#{destination}/bin/git-write-tree").to be_a_file
          else
            expect("#{destination}/bin/git-tag").to be_a_hardlink
            expect("#{destination}/bin/git-write-tree").to be_a_hardlink
          end
        end
      end

      context "with deeply nested paths and symlinks", :not_supported_on_windows do
        let(:source) do
          source = File.join(tmp_path, "source")
          FileUtils.mkdir_p(source)

          create_directory(source, "bin")
          create_file(source, "bin", "apt")
          create_file(source, "bin", "yum")

          create_file(source, "LICENSE") { "MIT" }

          create_directory(source, "include")
          create_directory(source, "include", "linux")
          create_file(source, "include", "linux", "init.ini")

          create_directory(source, "source")
          create_directory(source, "source", "bin")
          create_file(source, "source", "bin", "apt")
          create_file(source, "source", "bin", "yum")
          create_file(source, "source", "LICENSE") { "Apache 2.0" }

          create_directory(source, "empty_directory")

          create_directory(source, "links")
          create_file(source, "links", "home.html")
          FileUtils.ln_s("./home.html", "#{source}/links/index.html")
          FileUtils.ln_s("./home.html", "#{source}/links/default.html")
          FileUtils.ln_s("../source/bin/apt", "#{source}/links/apt")

          FileUtils.ln_s("/foo/bar", "#{source}/root")

          source
        end

        it "copies relative and absolute symlinks" do
          described_class.sync(source, destination)

          expect("#{destination}/bin").to be_a_directory
          expect("#{destination}/bin/apt").to be_a_file
          expect("#{destination}/bin/yum").to be_a_file

          expect("#{destination}/LICENSE").to be_a_file

          expect("#{destination}/include").to be_a_directory
          expect("#{destination}/include/linux").to be_a_directory
          expect("#{destination}/include/linux/init.ini").to be_a_file

          expect("#{destination}/source").to be_a_directory
          expect("#{destination}/source/bin").to be_a_directory
          expect("#{destination}/source/bin/apt").to be_a_file
          expect("#{destination}/source/bin/yum").to be_a_file
          expect("#{destination}/source/LICENSE").to be_a_file

          expect("#{destination}/empty_directory").to be_a_directory

          expect("#{destination}/links").to be_a_directory
          expect("#{destination}/links/home.html").to be_a_file
          expect("#{destination}/links/index.html").to be_a_symlink_to("./home.html")
          expect("#{destination}/links/default.html").to be_a_symlink_to("./home.html")
          expect("#{destination}/links/apt").to be_a_symlink_to("../source/bin/apt")

          expect("#{destination}/root").to be_a_symlink_to("/foo/bar")
        end
      end

      context "when :exclude is given" do
        it "does not copy files and folders that match the pattern" do
          described_class.sync(source, destination, exclude: ".dot_folder")

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to_not be_a_directory
          expect("#{destination}/.dot_folder/file_f").to_not be_a_file
          expect("#{destination}/.file_g").to be_a_file
        end

        it "does not copy files and folders that match the wildcard pattern" do
          described_class.sync(source, destination, exclude: "nested/*/folder")

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to be_a_directory
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file
          expect("#{destination}/nested/deep/folder/file_h").to_not be_a_file
          expect("#{destination}/nested/deep/folder/file_i").to_not be_a_file
          expect("#{destination}/nested/deep/deep/folder/file_j").to be_a_file
          expect("#{destination}/nested/deep/deep/folder/file_k").to be_a_file
        end

        it "does not copy files and folders that match the super wildcard pattern" do
          described_class.sync(source, destination, exclude: "nested/**/folder")

          expect("#{destination}/file_a").to be_a_file
          expect("#{destination}/file_b").to be_a_file
          expect("#{destination}/file_c").to be_a_file
          expect("#{destination}/folder/file_d").to be_a_file
          expect("#{destination}/folder/file_e").to be_a_file
          expect("#{destination}/.dot_folder").to be_a_directory
          expect("#{destination}/.dot_folder/file_f").to be_a_file
          expect("#{destination}/.file_g").to be_a_file
          expect("#{destination}/nested/deep/folder/file_h").to_not be_a_file
          expect("#{destination}/nested/deep/folder/file_i").to_not be_a_file
          expect("#{destination}/nested/deep/deep/folder/file_j").to_not be_a_file
          expect("#{destination}/nested/deep/deep/folder/file_k").to_not be_a_file
        end

        it "removes existing files and folders in destination" do
          FileUtils.mkdir_p("#{destination}/existing_folder")
          FileUtils.touch("#{destination}/existing_file")
          FileUtils.mkdir_p("#{destination}/.dot_folder")
          FileUtils.touch("#{destination}/.dot_folder/file_f")

          described_class.sync(source, destination, exclude: ".dot_folder")

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
