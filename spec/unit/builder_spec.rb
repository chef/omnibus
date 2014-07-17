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

      it_behaves_like 'a cleanroom setter', :command, <<-EOH
        command 'echo "hello"'
      EOH
      it_behaves_like 'a cleanroom setter', :patch, <<-EOH
        patch source: 'diff.patch'
      EOH
      it_behaves_like 'a cleanroom getter', :max_build_jobs
      it_behaves_like 'a cleanroom setter', :ruby, <<-EOH
        ruby '-e "puts"'
      EOH
      it_behaves_like 'a cleanroom setter', :gem, <<-EOH
        gem 'install bacon'
      EOH
      it_behaves_like 'a cleanroom setter', :bundle, <<-EOH
        bundle 'install'
      EOH
      it_behaves_like 'a cleanroom setter', :block, <<-EOH
        block 'A named block' do
          puts "this is a block"
        end
      EOH
      it_behaves_like 'a cleanroom setter', :erb, <<-EOH
        erb source: 'template.erb'
      EOH
      it_behaves_like 'a cleanroom setter', :mkdir, <<-EOH
        mkdir 'path'
      EOH
      it_behaves_like 'a cleanroom setter', :touch, <<-EOH
        touch 'file'
      EOH
      it_behaves_like 'a cleanroom setter', :delete, <<-EOH
        delete 'file'
      EOH
      it_behaves_like 'a cleanroom setter', :copy, <<-EOH
        copy 'file', 'file2'
      EOH
      it_behaves_like 'a cleanroom setter', :move, <<-EOH
        move 'file', 'file2'
      EOH
      it_behaves_like 'a cleanroom setter', :link, <<-EOH
        link 'file', 'file2'
      EOH
      it_behaves_like 'a cleanroom getter', :project_root, <<-EOH
        puts project_root
      EOH

      # From software
      it_behaves_like 'a cleanroom getter', :project_dir
      it_behaves_like 'a cleanroom getter', :install_dir
    end
  end
end
