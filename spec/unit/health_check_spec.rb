require 'spec_helper'

describe Omnibus::HealthCheck do
  context 'on linux' do
    before { stub_ohai(platform: 'ubuntu', version: '12.04') }

    context 'without external dependencies' do
      it 'should not raise' do
        expect(Mixlib::ShellOut).to receive(:new).with('find /project/ -type f | xargs ldd', timeout: 3600).and_return(Mixlib::ShellOut.new("cat #{fixtures_path}/health_check/linux-good.log"))

        expect { Omnibus::HealthCheck.run('/project') }.to_not raise_error
      end
    end

    context 'with external dependencies' do
      it 'should raise' do
        expect(Mixlib::ShellOut).to receive(:new).with('find /project/ -type f | xargs ldd', timeout: 3600).and_return(Mixlib::ShellOut.new("cat #{fixtures_path}/health_check/linux-bad.log"))

        expect { Omnibus::HealthCheck.run('/project') }.to raise_error
      end
    end
  end
end
