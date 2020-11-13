require "spec_helper"

module Omnibus
  describe Builder do
    let(:software) do
      double(Software,
        name: "chefdk",
        install_dir: project_dir,
        project_dir: project_dir)
    end

    let(:project_dir) { on_windows ? "C:/opscode/chefdk" : "/opt/chefdk" }
    let(:on_windows) { false }
    let(:msys_bash) { "C:\\opscode\\chefdk\\embedded\\msys\\1.0\\bin\\bash.exe" }

    def run_build_command
      subject.send(:build_commands)[0].run(subject)
    end

    subject { described_class.new(software) }

    before do
      allow(subject).to receive(:windows?).and_return(on_windows)
      allow(subject).to receive(:windows_safe_path) do |*args|
        path = File.join(*args)
        path.gsub!(File::SEPARATOR, '\\') if on_windows
      end
    end

    describe "#command" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:command)
      end
    end

    describe "#workers" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:workers)
      end
    end

    describe "#ruby" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:ruby)
      end
    end

    describe "#gem" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:gem)
      end
    end

    describe "#bundle" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:bundle)
      end
    end

    describe "#appbundle" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:appbundle)
      end
    end

    describe "#block" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:block)
      end
    end

    describe "#erb" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:erb)
      end
    end

    describe "#mkdir" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:mkdir)
      end
    end

    describe "#touch" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:touch)
      end
    end

    describe "#delete" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:delete)
      end
    end

    describe "#strip" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:strip)
      end
    end

    describe "#copy" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:copy)
      end
    end

    describe "#move" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:move)
      end
    end

    describe "#link" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:link)
      end
    end

    describe "#sync" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:sync)
      end
    end

    describe "#update_config_guess" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:update_config_guess)
      end
    end

    describe "#windows_safe_path" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:windows_safe_path)
      end
    end

    describe "#project_dir" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:project_dir)
      end
    end

    describe "#install_dir" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:install_dir)
      end
    end

    describe "#overrides" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:overrides)
      end
    end

    describe "#make" do
      before do
        allow(subject).to receive(:command)
      end

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:make)
      end

      context "when :bin is present" do
        it "uses the custom bin" do
          expect(subject).to receive(:command)
            .with("/path/to/make", in_msys_bash: true)
          subject.make(bin: "/path/to/make")
        end
      end

      context "when gmake is present" do
        before do
          allow(Omnibus).to receive(:which)
            .with("gmake")
            .and_return("/bin/gmake")
        end

        it "uses gmake and sets MAKE=gmake" do
          expect(subject).to receive(:command)
            .with("gmake", env: { "MAKE" => "gmake" }, in_msys_bash: true)
          subject.make
        end
      end

      context "when gmake is not present" do
        before do
          allow(Omnibus).to receive(:which)
            .and_return(nil)
        end

        it "uses make" do
          expect(subject).to receive(:command)
            .with("make", in_msys_bash: true)
          subject.make
        end
      end

      it "accepts 0 options" do
        expect(subject).to receive(:command)
          .with("make", in_msys_bash: true)
        expect { subject.make }.to_not raise_error
      end

      it "accepts an additional command string" do
        expect(subject).to receive(:command)
          .with("make install", in_msys_bash: true)
        expect { subject.make("install") }.to_not raise_error
      end

      it "persists given options" do
        expect(subject).to receive(:command)
          .with("make", timeout: 3600, in_msys_bash: true)
        subject.make(timeout: 3600)
      end
    end

    describe "#configure" do
      before do
        allow(subject).to receive(:command)
      end

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:configure)
      end

      context "on 64-bit windows" do
        let(:on_windows) { true }
        let(:windows_i386) { false }

        before do
          allow(subject).to receive(:windows_arch_i386?)
            .and_return(windows_i386)
        end

        it "appends platform host to the options" do
          expect(subject).to receive(:command)
            .with("./configure --build=x86_64-w64-mingw32 --prefix=#{project_dir}/embedded", in_msys_bash: true)
          subject.configure
        end
      end

      context "on 32-bit windows" do
        let(:on_windows) { true }
        let(:windows_i386) { true }

        before do
          allow(subject).to receive(:windows_arch_i386?)
            .and_return(windows_i386)
        end

        it "appends platform host to the options" do
          expect(subject).to receive(:command)
            .with("./configure --build=i686-w64-mingw32 --prefix=#{project_dir}/embedded", in_msys_bash: true)
          subject.configure
        end
      end

      context "when :bin is present" do
        it "uses the custom bin" do
          expect(subject).to receive(:command)
            .with("/path/to/configure --prefix=#{project_dir}/embedded", in_msys_bash: true)
          subject.configure(bin: "/path/to/configure")
        end
      end

      context "when :prefix is present" do
        it "emits non-empty prefix" do
          expect(subject).to receive(:command)
            .with("./configure --prefix=/some/prefix", in_msys_bash: true)
          subject.configure(prefix: "/some/prefix")
        end

        it "omits prefix if empty" do
          expect(subject).to receive(:command)
            .with("./configure", in_msys_bash: true)
          subject.configure(prefix: "")
        end
      end

      it "accepts 0 options" do
        expect(subject).to receive(:command)
          .with("./configure --prefix=#{project_dir}/embedded", in_msys_bash: true)
        expect { subject.configure }.to_not raise_error
      end

      it "accepts an additional command string" do
        expect(subject).to receive(:command)
          .with("./configure --prefix=#{project_dir}/embedded --myopt", in_msys_bash: true)
        expect { subject.configure("--myopt") }.to_not raise_error
      end

      it "persists given options" do
        expect(subject).to receive(:command)
          .with("./configure --prefix=#{project_dir}/embedded", timeout: 3600, in_msys_bash: true)
        subject.configure(timeout: 3600)
      end
    end

    describe "#patch" do
      before do
        allow(subject).to receive(:find_file)
          .with("config/patches", "good_patch")
          .and_return(
            [ ["#{project_dir}/patch_location1/good_patch", "#{project_dir}/patch_location2/good_patch"],
              "#{project_dir}/patch_location2/good_patch" ]
          )
      end

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:patch)
      end

      it "invokes patch with patch level 1 unless specified" do
        expect { subject.patch(source: "good_patch") }.to_not raise_error
        expect(subject).to receive(:shellout!)
          .with("patch -p1 -i #{project_dir}/patch_location2/good_patch", in_msys_bash: true)
        run_build_command
      end

      it "invokes patch with patch level provided" do
        expect { subject.patch(source: "good_patch", plevel: 0) }.to_not raise_error
        expect(subject).to receive(:shellout!)
          .with("patch -p0 -i #{project_dir}/patch_location2/good_patch", in_msys_bash: true)
        run_build_command
      end

      it "invokes patch differently if target is provided" do
        expect { subject.patch(source: "good_patch", target: "target/path") }.to_not raise_error
        expect(subject).to receive(:shellout!)
          .with("cat #{project_dir}/patch_location2/good_patch | patch -p1 target/path", in_msys_bash: true)
        run_build_command
      end

      it "persists other options" do
        expect { subject.patch(source: "good_patch", timeout: 3600) }.to_not raise_error
        expect(subject).to receive(:shellout!)
          .with("patch -p1 -i #{project_dir}/patch_location2/good_patch", timeout: 3600, in_msys_bash: true)
        run_build_command
      end
    end

    describe "#shasum" do
      let(:build_step) do
        Proc.new do
          block do
            command("true")
          end
        end
      end

      let(:tmp_dir) { Dir.mktmpdir }
      after { FileUtils.rmdir(tmp_dir) }

      let(:software) do
        double(Software,
          name: "chefdk",
          install_dir: tmp_dir,
          project_dir: tmp_dir,
          overridden?: false)
      end

      let(:before_build_shasum) do
        b = described_class.new(software)
        b.evaluate(&build_step)
        b.shasum
      end

      it "returns the same value when called before or after the build" do
        subject.evaluate(&build_step)
        subject.build
        expect(subject.shasum).to eq(before_build_shasum)
      end
    end
  end
end
