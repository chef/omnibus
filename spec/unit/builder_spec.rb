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

    context 'DSL methods' do
      before do
        allow(subject).to receive(:find_file).and_return([nil, '/path'])
      end

      it_behaves_like 'a cleanroom setter', :command, %|command 'echo "hello"'|
      it_behaves_like 'a cleanroom setter', :patch, %|patch source: 'diff.patch'|
      it_behaves_like 'a cleanroom getter', :workers
      it_behaves_like 'a cleanroom getter', :max_build_jobs
      it_behaves_like 'a cleanroom setter', :ruby, %|ruby '-e "puts"'|
      it_behaves_like 'a cleanroom setter', :gem, %|gem 'install bacon'|
      it_behaves_like 'a cleanroom setter', :bundle, %|bundle 'install'|
      it_behaves_like 'a cleanroom setter', :block, <<-EOH.gsub(/^ {8}/, '')
        block 'A named block' do
          # Complex operation
        end
      EOH
      it_behaves_like 'a cleanroom setter', :erb,  <<-EOH.gsub(/^ {8}/, '')
        erb source: 'template.erb',
            dest: '/path/to/file',
            vars: { a: 'b', c: 'd' }
      EOH
      it_behaves_like 'a cleanroom setter', :mkdir, %|mkdir 'path'|
      it_behaves_like 'a cleanroom setter', :touch, %|touch 'file'|
      it_behaves_like 'a cleanroom setter', :delete, %|delete 'file'|
      it_behaves_like 'a cleanroom setter', :copy, %|copy 'file', 'file2'|
      it_behaves_like 'a cleanroom setter', :move, %|move 'file', 'file2'|
      it_behaves_like 'a cleanroom setter', :link, %|link 'file', 'file2'|
      it_behaves_like 'a cleanroom setter', :sync, %|sync 'a/', 'b/'|
      it_behaves_like 'a cleanroom getter', :project_root, %|puts project_root|
      it_behaves_like 'a cleanroom getter', :windows_safe_path, %|puts windows_safe_path('foo')|

      # From software
      it_behaves_like 'a cleanroom getter', :project_dir
      it_behaves_like 'a cleanroom getter', :install_dir
    end

    describe '#max_build_jobs' do
      before { allow(subject).to receive(:workers).and_return(5) }

      it 'prints a deprecation' do
        output = capture_logging { subject.max_build_jobs }
        expect(output).to include("Please use `workers' instead.")
      end

      it 'delegates to #workers' do
        expect(subject).to receive(:workers).once
        subject.max_build_jobs
      end
    end
  end
end
