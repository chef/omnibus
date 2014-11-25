require 'spec_helper'
require 'pathname'

module Omnibus
  describe HealthCheck do
    let(:project) do
      double(Project,
        name: 'chefdk',
        install_dir: '/opt/chefdk',
        dest_dir: '/',
        library: double(Library,
          components: [],
        ),
      )
    end

    subject { described_class.new(project) }

    context 'on linux' do
      before { stub_ohai(platform: 'ubuntu', version: '12.04') }

      let(:bad_healthcheck) do
        double('Mixlib::Shellout',
          stdout: <<-EOH.gsub(/^ {12}/, '')
            /bin/ls:
              linux-vdso.so.1 =>  (0x00007fff583ff000)
              libselinux.so.1 => /lib/x86_64-linux-gnu/libselinux.so.1 (0x00007fad8592a000)
              librt.so.1 => /lib/x86_64-linux-gnu/librt.so.1 (0x00007fad85722000)
              libacl.so.1 => /lib/x86_64-linux-gnu/libacl.so.1 (0x00007fad85518000)
              libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fad8518d000)
              libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007fad84f89000)
              /lib64/ld-linux-x86-64.so.2 (0x00007fad85b51000)
              libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007fad84d6c000)
              libattr.so.1 => /lib/x86_64-linux-gnu/libattr.so.1 (0x00007fad84b67000)
            /bin/cat:
              linux-vdso.so.1 =>  (0x00007fffa4dcf000)
              libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f4a858cd000)
              /lib64/ld-linux-x86-64.so.2 (0x00007f4a85c5f000)
          EOH
        )
      end

      let(:good_healthcheck) do
        double('Mixlib::Shellout',
          stdout: <<-EOH.gsub(/^ {12}/, '')
            /bin/echo:
              linux-vdso.so.1 =>  (0x00007fff8a6ee000)
              libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f70f58c0000)
              /lib64/ld-linux-x86-64.so.2 (0x00007f70f5c52000)
            /bin/cat:
              linux-vdso.so.1 =>  (0x00007fff095b3000)
              libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fe868ec0000)
              /lib64/ld-linux-x86-64.so.2 (0x00007fe869252000)
          EOH
        )
      end

      it 'raises an exception when there are external dependencies' do
        allow(subject).to receive(:shellout)
          .with("find #{Pathname.new(File.join(project.dest_dir, project.install_dir)).cleanpath.to_s}/ -type f | xargs ldd")
          .and_return(bad_healthcheck)

        expect { subject.run! }.to raise_error(HealthCheckFailed)
      end

      it 'does not raise an exception when the healthcheck passes' do
        allow(subject).to receive(:shellout)
          .with("find #{Pathname.new(File.join(project.dest_dir, project.install_dir)).cleanpath.to_s}/ -type f | xargs ldd")
          .and_return(good_healthcheck)

        expect { subject.run! }.to_not raise_error
      end
    end
  end
end
