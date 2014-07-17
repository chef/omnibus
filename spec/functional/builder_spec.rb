require 'spec_helper'

module Omnibus
  describe Builder do
    let(:software) do
      double(Software,
        name: 'chefdk',
        install_dir: File.join(tmp_path, 'chefdk'),
        project_dir: File.join(tmp_path, 'chefdk', 'cache'),
        overridden?: false,
      )
    end

    #
    # Fakes the embedded bin path to whatever exists in bundler. This is useful
    # for testing methods like +ruby+ and +rake+ without the need to compile
    # a real Ruby just for functional tests.
    #
    def fake_embedded_bin(name)
      bin = File.join(software.install_dir, 'embedded', 'bin')

      FileUtils.mkdir_p(bin)
      FileUtils.ln_s(Bundler.which(name), File.join(bin, name))
    end

    subject { described_class.new(software) }

    before do
      Config.project_root(tmp_path)
      Config.build_retries(0)
      Config.use_git_caching(false)
      Config.software_gems(nil)

      # Make the directories
      FileUtils.mkdir_p(software.install_dir)
      FileUtils.mkdir_p(software.project_dir)
      FileUtils.mkdir_p(File.join(tmp_path, 'config', 'software'))
      FileUtils.mkdir_p(File.join(tmp_path, 'config', 'patches'))
      FileUtils.mkdir_p(File.join(tmp_path, 'config', 'templates'))
    end

    describe '#command' do
      it 'executes the command' do
        path = File.join(software.install_dir, 'file.txt')
        subject.command("echo 'Hello World!'")

        output = capture_logging { subject.build }
        expect(output).to include('Hello World')
      end
    end

    describe '#patch' do
      it 'applies the patch' do
        configure = File.join(tmp_path, 'chefdk', 'cache', 'configure')
        FileUtils.mkdir_p(File.dirname(configure))
        File.open(configure, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            THING="-e foo"
            ZIP="zap"
          EOH
        end

        patch = File.join(tmp_path, 'config', 'patches', 'chefdk', 'apply.patch')
        FileUtils.mkdir_p(File.dirname(patch))
        File.open(patch, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            --- a/configure
            +++ b/configure
            @@ -1,2 +1,3 @@
             THING="-e foo"
            +FOO="bar"
             ZIP="zap"
          EOH
        end

        subject.patch(source: 'apply.patch')
        subject.build
      end
    end

    describe '#ruby' do
      it 'executes the command as the embdedded ruby' do
        ruby = File.join(tmp_path, 'chefdk', 'scripts', 'setup.rb')
        FileUtils.mkdir_p(File.dirname(ruby))
        File.open(ruby, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            File.write("#{software.install_dir}/test.txt", 'This is content!')
          EOH
        end

        fake_embedded_bin('ruby')

        subject.ruby(ruby)
        subject.build

        path = "#{software.install_dir}/test.txt"
        expect(File.exist?(path)).to be_truthy
        expect(File.read(path)).to eq('This is content!')
      end
    end

    describe '#gem' do
      it 'executes the command as the embedded gem' do
        gemspec = File.join(tmp_path, 'example.gemspec')
        File.open(gemspec, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            Gem::Specification.new do |gem|
              gem.name           = 'example'
              gem.version        = '1.0.0'
              gem.author         = 'Chef Software, Inc.'
              gem.email          = 'info@getchef.com'
              gem.description    = 'Installs a thing'
              gem.summary        = gem.description
            end
          EOH
        end

        fake_embedded_bin('gem')

        subject.gem("build #{gemspec}")
        subject.gem("install #{tmp_path}/chefdk/cache/example-1.0.0.gem")
        output = capture_logging { subject.build }

        expect(output).to include('gem build')
        expect(output).to include('gem install')
      end
    end

    describe '#bundler' do
      it 'executes the command as the embedded bundler' do
        gemspec = File.join(tmp_path, 'example.gemspec')
        File.open(gemspec, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            Gem::Specification.new do |gem|
              gem.name           = 'example'
              gem.version        = '1.0.0'
              gem.author         = 'Chef Software, Inc.'
              gem.email          = 'info@getchef.com'
              gem.description    = 'Installs a thing'
              gem.summary        = gem.description
            end
          EOH
        end

        gemfile = File.join(tmp_path, 'Gemfile')
        File.open(gemfile, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            gemspec
          EOH
        end

        fake_embedded_bin('bundle')

        subject.bundle('install')
        output = capture_logging { subject.build }

        expect(output).to include('bundle install')
      end
    end

    describe '#rake' do
      it 'executes the command as the embedded rake' do
        rakefile = File.join(tmp_path, 'Rakefile')
        File.open(rakefile, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            task(:foo) {  }
          EOH
        end

        fake_embedded_bin('rake')

        subject.rake('-T')
        subject.rake('foo')
        output = capture_logging { subject.build }

        expect(output).to include('rake -T')
        expect(output).to include('rake foo')
      end
    end

    describe '#block' do
      it 'executes the command as a block' do
        subject.block('A complex operation') do
          FileUtils.touch("#{project_dir}/bacon")
        end
        output = capture_logging { subject.build }

        expect(output).to include('A complex operation')
        expect(File.exist?("#{software.project_dir}/bacon")).to be_truthy
      end
    end

    describe '#erb' do
      it 'renders the erb' do
        erb = File.join(tmp_path, 'config', 'templates', 'chefdk', 'example.erb')
        FileUtils.mkdir_p(File.dirname(erb))
        File.open(erb, 'w') do |f|
          f.write <<-EOH.gsub(/^ {12}/, '')
            <%= a %>
            <%= b %>
          EOH
        end

        destination = File.join(tmp_path, 'rendered')

        subject.erb(
          source: 'example.erb',
          dest:   destination,
          vars:   { a: 'foo', b: 'bar' },
        )
        subject.build

        expect(File.exist?(destination)).to be_truthy
        expect(File.read(destination)).to eq("foo\nbar\n")
      end
    end

    describe '#mkdir' do
      it 'creates the directory' do
        path = File.join(tmp_path, 'scratch')
        FileUtils.rm_rf(path)

        subject.mkdir(path)
        subject.build

        expect(File.directory?(path)).to be_truthy
      end
    end

    describe '#touch' do
      it 'creates the file' do
        path = File.join(tmp_path, 'file')
        FileUtils.rm_rf(path)

        subject.touch(path)
        subject.build

        expect(File.file?(path)).to be_truthy
      end
    end

    describe '#delete' do
      it 'deletes the directory' do
        path = File.join(tmp_path, 'scratch')
        FileUtils.mkdir_p(path)

        subject.delete(path)
        subject.build

        expect(File.exist?(path)).to be_falsey
      end

      it 'deletes the file' do
        path = File.join(tmp_path, 'file')
        FileUtils.touch(path)

        subject.delete(path)
        subject.build

        expect(File.exist?(path)).to be_falsey
      end
    end

    describe '#copy' do
      it 'copies the file' do
        path_a = File.join(tmp_path, 'file1')
        path_b = File.join(tmp_path, 'file2')
        FileUtils.touch(path_a)

        subject.copy(path_a, path_b)
        subject.build

        expect(File.file?(path_b)).to be_truthy
        expect(File.read(path_b)).to eq(File.read(path_a))
      end
    end

    describe '#move' do
      it 'moves the file' do
        path_a = File.join(tmp_path, 'file1')
        path_b = File.join(tmp_path, 'file2')
        FileUtils.touch(path_a)

        subject.move(path_a, path_b)
        subject.build

        expect(File.file?(path_b)).to be_truthy
        expect(File.file?(path_a)).to be_falsey
      end
    end

    describe '#link' do
      it 'links the file' do
        path_a = File.join(tmp_path, 'file1')
        path_b = File.join(tmp_path, 'file2')
        FileUtils.touch(path_a)

        subject.link(path_a, path_b)
        subject.build

        expect(File.symlink?(path_b)).to be_truthy
      end
    end
  end
end
