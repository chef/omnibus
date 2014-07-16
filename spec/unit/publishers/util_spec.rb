require 'spec_helper'

module Omnibus
  describe Util do
    describe '#truncate_platform_version' do
      let(:subject) { Class.new { extend Util } }

      shared_examples 'a version manipulator' do |platform_shortname, version, expected|
        context "on #{platform_shortname}-#{version}" do
          it 'returns the correct value' do
            expect(subject.truncate_platform_version(version, platform_shortname)).to eq(expected)
          end
        end
      end

      it_behaves_like 'a version manipulator', 'arch', '2009.02', '2009.02'
      it_behaves_like 'a version manipulator', 'arch', '2014.06.01', '2014.06'
      it_behaves_like 'a version manipulator', 'debian', '7.1', '7'
      it_behaves_like 'a version manipulator', 'debian', '6.9', '6'
      it_behaves_like 'a version manipulator', 'ubuntu', '10.04', '10.04'
      it_behaves_like 'a version manipulator', 'ubuntu', '10.04.04', '10.04'
      it_behaves_like 'a version manipulator', 'fedora', '11.5', '11'
      it_behaves_like 'a version manipulator', 'freebsd', '10.0', '10'
      it_behaves_like 'a version manipulator', 'rhel', '6.5', '6'
      it_behaves_like 'a version manipulator', 'el', '6.5', '6'
      it_behaves_like 'a version manipulator', 'centos', '5.9.6', '5'
      it_behaves_like 'a version manipulator', 'aix', '7.1', '7.1'
      it_behaves_like 'a version manipulator', 'gentoo', '2004.3', '2004.3'
      it_behaves_like 'a version manipulator', 'mac_os_x', '10.9.1', '10.9'
      it_behaves_like 'a version manipulator', 'openbsd', '5.4.4', '5.4'
      it_behaves_like 'a version manipulator', 'slackware', '12.0.1', '12.0'
      it_behaves_like 'a version manipulator', 'solaris2', '5.9', '5.9'
      it_behaves_like 'a version manipulator', 'suse', '5.9', '5.9'
      it_behaves_like 'a version manipulator', 'omnios', 'r151010', 'r151010'
      it_behaves_like 'a version manipulator', 'smartos', '20120809T221258Z', '20120809T221258Z'
      it_behaves_like 'a version manipulator', 'windows', '5.0.2195', '2000'
      it_behaves_like 'a version manipulator', 'windows', '5.1.2600', 'xp'
      it_behaves_like 'a version manipulator', 'windows', '5.2.3790', '2003r2'
      it_behaves_like 'a version manipulator', 'windows', '6.0.6001', '2008'
      it_behaves_like 'a version manipulator', 'windows', '6.1.7600', '7'
      it_behaves_like 'a version manipulator', 'windows', '6.1.7601', '2008r2'
      it_behaves_like 'a version manipulator', 'windows', '6.2.9200', '8'
      it_behaves_like 'a version manipulator', 'windows', '6.3.9200', '8.1'

      context 'given an unknown platform' do
        it 'raises an exception' do
          expect { subject.truncate_platform_version('1.crispy', 'bacon') }
            .to raise_error(UnknownPlatform)
        end
      end

      context 'given an unknown windows platform version' do
        it 'raises an exception' do
          expect { subject.truncate_platform_version('1.2.3', 'windows') }
            .to raise_error(UnknownPlatformVersion)
        end
      end
    end
  end
end
