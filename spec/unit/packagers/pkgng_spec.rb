require "spec_helper"

module Omnibus
  describe Packager::PKGNG do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
        project.license(project_license) if project_license
      end
    end

    subject { described_class.new(project) }

    let(:project_license) { nil }
    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
    end

    describe "#origin" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:origin)
      end

      it "has a default value" do
        expect(subject.origin).to eq("omnibus/project")
      end

      it "must be a string" do
        expect { subject.origin(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#comment" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:comment)
      end

      it "has a default value" do
        expect(subject.comment).to eq("The full stack of project")
      end

      it "must be a string" do
        expect { subject.comment(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#prefix" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:prefix)
      end

      it "has a default value" do
        expect(subject.prefix).to eq("/")
      end

      it "must be a string" do
        expect { subject.prefix(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#licenses" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:licenses)
      end

      it "has a default value" do
        expect(subject.licenses).to eq(["Unspecified"])
      end

      it "must be an array" do
        expect { subject.licenses(Object.new) }.to raise_error(InvalidValue)
      end

      context "with project license" do
        let(:project_license) { "custom-license" }

        it "uses project license" do
          expect(subject.licenses).to eq(["custom-license"])
        end
      end
    end

    describe "#groups" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:groups)
      end

      it "has a default value" do
        expect(subject.groups).to eq(["root"])
      end

      it "must be an array" do
        expect { subject.groups(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#users" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:users)
      end

      it "has a default value" do
        expect(subject.users).to eq(["root"])
      end

      it "must be an array" do
        expect { subject.users(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#categories" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:categories)
      end

      it "has a default value" do
        expect(subject.categories).to eq(["misc"])
      end

      it "must be an array" do
        expect { subject.categories(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#runtime_dependencies" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:runtime_dependencies)
      end

      it "has a default value" do
        expect(subject.runtime_dependencies).to eq({})
      end

      it "must be a hash" do
        expect { subject.runtime_dependencies(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#options" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:options)
      end

      it "has a default value" do
        expect(subject.options).to eq({})
      end

      it "must be a hash" do
        expect { subject.options(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#id" do
      it "is :pkgng" do
        expect(subject.id).to eq(:pkgng)
      end
    end

    describe "#package_name" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "includes the name, version, arch, and build iteration" do
        expect(subject.package_name).to eq("project-1.2.3_2.txz")
      end
    end

    describe "#write_compact_manifest" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "generates the file" do
        subject.write_compact_manifest
        expect("#{staging_dir}/+COMPACT_MANIFEST").to be_a_file
      end

      it "has the correct content" do
        subject.write_compact_manifest
        contents = File.read("#{staging_dir}/+COMPACT_MANIFEST")
        manifest = JSON.parse(contents)

        expect(manifest["name"]).to eq("project")
        expect(manifest["version"]).to eq("1.2.3_2")
        expect(manifest["origin"]).to eq("omnibus/project")
        expect(manifest["comment"]).to eq("The full stack of project")
        expect(manifest["arch"]).to eq("amd64")
        expect(manifest["www"]).to eq("https://example.com")
        expect(manifest["maintainer"]).to eq("Chef Software")
        expect(manifest["prefix"]).to eq("/")
        expect(manifest["licenses"]).to eq(["Unspecified"])
        expect(manifest["flatsize"]).to eq(0)
        expect(manifest["users"]).to eq(["root"])
        expect(manifest["groups"]).to eq(["root"])
        expect(manifest["options"]).to eq({})
        expect(manifest["desc"]).to eq("The full stack of project")
        expect(manifest["categories"]).to eq(["misc"])
        expect(manifest["deps"]).to eq({})
      end
    end

    describe "#write_manifest" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "generates the file" do
        subject.write_manifest
        expect("#{staging_dir}/+MANIFEST").to be_a_file
      end

      it "has the correct content" do
        subject.write_manifest
        contents = File.read("#{staging_dir}/+MANIFEST")
        manifest = JSON.parse(contents)

        expect(manifest["name"]).to eq("project")
        expect(manifest["files"]).to eq({})
        expect(manifest["directories"]).to eq({})
        expect(manifest["scripts"]).to eq({})
      end
    end

    describe "#package_size" do
      before do
        project.install_dir(staging_dir)

        create_file("#{staging_dir}/file1") { "1" * 10_000 }
        create_file("#{staging_dir}/file2") { "2" * 20_000 }
      end

      it "stats all the files in the install_dir" do
        expect(subject.package_size).to eq(29)
      end
    end

    describe "#safe_base_package_name" do
      context 'when the project name is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_base_package_name).to eq("project")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project name has invalid characters" do
        before { project.name("Pro$ject123.for-realz_2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_base_package_name).to eq("pro-ject123.for-realz-2")
          end

          expect(output).to include("The `name' component of FreeBSD package names can only include")
        end
      end
    end

    describe "#safe_build_iteration" do
      it "returns the build iteration" do
        expect(subject.safe_build_iteration).to eq(project.build_iteration)
      end
    end

    describe "#safe_version" do
      context 'when the project build_version is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_version).to eq("1.2.3")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project build_version has dashes" do
        before { project.build_version("1.2-rc.1") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2_rc.1")
          end

          expect(output).to include("FreeBSD package versions cannot contain dashes or strings.")
        end
      end

      context "when the project build_version has invalid characters" do
        before { project.build_version("1.2$alpha.~##__2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2_alpha.~_2")
          end

          expect(output).to include("The `version' component of FreeBSD package names can only include")
        end
      end
    end

    describe "#safe_architecture" do
      context "when i386" do
        before do
          stub_ohai(platform: "freebsd", version: "10.3") do |data|
            data["kernel"]["machine"] = "i386"
          end
        end

        it "returns i386" do
          expect(subject.safe_architecture).to eq("i386")
        end
      end

      context "when i686" do
        before do
          stub_ohai(platform: "freebsd", version: "10.3") do |data|
            data["kernel"]["machine"] = "i686"
          end
        end

        it "returns i386" do
          expect(subject.safe_architecture).to eq("i386")
        end
      end

      context "when amd64" do
        before do
          stub_ohai(platform: "freebsd", version: "10.3") do |data|
            data["kernel"]["machine"] = "amd64"
          end
        end

        it "returns amd64" do
          expect(subject.safe_architecture).to eq("amd64")
        end
      end
    end

    describe "#write_scripts" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
        create_file("#{project_root}/package-scripts/project/preinst") { "preinst" }
        create_file("#{project_root}/package-scripts/project/postinst") { "postinst" }
        create_file("#{project_root}/package-scripts/project/inst") { "inst" }
        create_file("#{project_root}/package-scripts/project/prerm") { "prerm" }
        create_file("#{project_root}/package-scripts/project/postrm") { "postrm" }
        create_file("#{project_root}/package-scripts/project/rm") { "rm" }
        create_file("#{project_root}/package-scripts/project/preup") { "preup" }
        create_file("#{project_root}/package-scripts/project/postup") { "postup" }
        create_file("#{project_root}/package-scripts/project/up") { "up" }
      end

      it "adds the scripts to the manifest" do
        subject.write_manifest
        contents = File.read("#{staging_dir}/+MANIFEST")
        scripts = JSON.parse(contents)["scripts"]

        expect(scripts.keys).to include("pre-install")
        expect(scripts.keys).to include("post-install")
        expect(scripts.keys).to include("install")
        expect(scripts.keys).to include("pre-deinstall")
        expect(scripts.keys).to include("post-deinstall")
        expect(scripts.keys).to include("deinstall")
        expect(scripts.keys).to include("pre-upgrade")
        expect(scripts.keys).to include("post-upgrade")
        expect(scripts.keys).to include("upgrade")

        expect(scripts["pre-install"]).to eq("preinst")
        expect(scripts["post-install"]).to eq("postinst")
        expect(scripts["install"]).to eq("inst")
        expect(scripts["pre-deinstall"]).to eq("prerm")
        expect(scripts["post-deinstall"]).to eq("postrm")
        expect(scripts["deinstall"]).to eq("rm")
        expect(scripts["pre-upgrade"]).to eq("preup")
        expect(scripts["post-upgrade"]).to eq("postup")
        expect(scripts["upgrade"]).to eq("up")
      end

      it "logs a message" do
        output = capture_logging do
          subject.write_manifest
        end

        expect(output).to include("Adding script `preinst'")
        expect(output).to include("Adding script `postinst'")
        expect(output).to include("Adding script `inst'")
        expect(output).to include("Adding script `prerm'")
        expect(output).to include("Adding script `postrm'")
        expect(output).to include("Adding script `rm'")
        expect(output).to include("Adding script `preup'")
        expect(output).to include("Adding script `postup'")
        expect(output).to include("Adding script `up'")
      end
    end
  end
end
