require 'spec_helper'

module Omnibus
  describe Builder do
    let(:software) do
      double(Software,
        name: 'chefdk',
        install_dir: '/opt/chefdk',
        project_dir: '/opt/chefdk',
      )
    end

    subject { described_class.new(software) }

    describe '#command' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:command)
      end
    end

    describe '#patch' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:patch)
      end
    end

    describe '#max_build_jobs' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:max_build_jobs)
      end
    end

    describe '#ruby' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:ruby)
      end
    end

    describe '#gem' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:gem)
      end
    end

    describe '#bundle' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:bundle)
      end
    end

    describe '#block' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:block)
      end
    end

    describe '#erb' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:erb)
      end
    end

    describe '#mkdir' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:mkdir)
      end
    end

    describe '#touch' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:touch)
      end
    end

    describe '#delete' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:delete)
      end
    end

    describe '#copy' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:copy)
      end
    end

    describe '#move' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:move)
      end
    end

    describe '#link' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:link)
      end
    end

    describe '#sync' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:sync)
      end
    end

    describe '#windows_safe_path' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:windows_safe_path)
      end
    end

    describe '#project_dir' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:project_dir)
      end
    end

    describe '#install_dir' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:install_dir)
      end
    end

    describe '#make' do
      before do
        allow(subject).to receive(:command)
      end

      context 'when :bin is present' do
        it 'uses the custom bin' do
          expect(subject).to receive(:command)
            .with('/path/to/make', {})
          subject.make(bin: '/path/to/make')
        end
      end

      context 'when gmake is present' do
        before do
          allow(Omnibus).to receive(:which)
            .with('gmake')
            .and_return('/bin/gmake')
        end

        it 'uses gmake and sets MAKE=gmake' do
          expect(subject).to receive(:command)
            .with('gmake', env: { 'MAKE' => 'gmake' })
          subject.make
        end
      end

      context 'when gmake is not present' do
        before do
          allow(Omnibus).to receive(:which)
            .and_return(nil)
        end

        it 'uses make' do
          expect(subject).to receive(:command)
            .with('make', {})
          subject.make
        end
      end

      it 'accepts 0 options' do
        expect { subject.make }.to_not raise_error
      end

      it 'accepts an additional command string' do
        expect { subject.make('install') }.to_not raise_error
      end

      it 'persists given options' do
        expect(subject).to receive(:command)
          .with(anything(), timeout: 3600)
        subject.make(timeout: 3600)
      end
    end
  end
end
