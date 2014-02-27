require 'omnibus/overrides'
require 'spec_helper'

describe Omnibus::Overrides do
  describe '#parse_file' do

    let(:overrides) { Omnibus::Overrides.parse_file(file) }
    subject { overrides }

    context 'with a valid overrides file' do
      let(:file) { overrides_path('good') }

      its(:size) { should eq(5) }
      its(['foo']) { should eq('1.2.3') }
      its(['bar']) { should eq('0.0.1') }
      its(['baz']) { should eq('deadbeefdeadbeefdeadbeefdeadbeef') }
      its(['spunky']) { should eq('master') }
      its(['monkey']) { should eq('release') }
    end

    context 'with an overrides file that contains a bad line' do
      let(:file) { overrides_path('bad_line') }

      it 'fails' do
        expect { overrides }.to raise_error(ArgumentError, "Invalid overrides line: 'THIS IS A BAD LINE'")
      end
    end

    context 'with an overrides file that contains duplicates' do
      let(:file) { overrides_path('with_dupes') }
      let(:duplicated_package) { 'erchef' }
      it 'fails' do
        expect { overrides }.to raise_error(ArgumentError, "Multiple overrides present for '#{duplicated_package}' in overrides file #{file}!")
      end
    end

    context "when passed 'nil'" do
      let(:file) { nil }
      it { should be_nil }
    end
  end # parse_file

  describe '#resolve_override_file' do
    before :each do
      @original = ENV['OMNIBUS_OVERRIDE_FILE']
      ENV['OMNIBUS_OVERRIDE_FILE'] = env_override_file
    end

    after :each do
      ENV['OMNIBUS_OVERRIDE_FILE'] = @original
    end

    subject { Omnibus::Overrides.resolve_override_file }

    context 'with no environment variable set' do
      let(:env_override_file) { nil }

      before :each do
        stub_const('Omnibus::Overrides::DEFAULT_OVERRIDE_FILE_NAME', new_default_file)
      end

      context 'and a non-existent overrides file' do
        let(:new_default_file) { '/this/file/totally/does/not/exist.txt' }
        it { should be_nil }
      end

      context 'with an existing overrides file' do
        let(:path) { overrides_path('good') }
        let(:new_default_file) { path }
        it { should eq(path) }
      end
    end # no environment variable

    context 'with OMNIBUS_OVERRIDE_FILE environment variable set' do
      context 'to an existing file' do
        let(:path) { overrides_path('good') }
        let(:env_override_file) { path  }
        it { should eq(path) }
      end

      context 'to a non-existent file' do
        let(:env_override_file) { '/this/file/totally/does/not/exist.txt' }
        it { should be_nil }
      end

      context 'to a non-existent file, but with an existing DEFAULT_OVERRIDE_FILE_NAME file' do
        let(:env_override_file) { '/this/file/totally/does/not/exist.txt' }
        let(:new_default_file) { overrides_path('good') }

        it "should still return 'nil', because environment variable has priority" do
          stub_const('Omnibus::Overrides::DEFAULT_OVERRIDE_FILE_NAME', new_default_file)

          expect(File.exist?(Omnibus::Overrides::DEFAULT_OVERRIDE_FILE_NAME)).to be_true
          expect(ENV['OMNIBUS_OVERRIDE_FILE']).to_not be_nil

          expect(subject).to be_nil
        end
      end
    end
  end

  describe '#overrides' do
    context 'when an overrides file cannot be found' do
      before :each do
        Omnibus::Overrides.stub(:resolve_override_file).and_return(nil)
      end

      it 'returns an empty hash' do
        expect(Omnibus::Overrides.overrides).to eq({})
      end
    end
  end

end
