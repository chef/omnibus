require 'rake/dsl_definition'
require 'omnibus/software'

require 'spec_helper'

describe Omnibus::Software do

  let(:project) do 
    p = mock(Omnibus::Project)
    p.should_receive(:install_path).any_number_of_times.and_return("monkeys")
    p
  end

  let(:software_name) {"erchef"}
  let(:software_file){ software_path(software_name) }
  let(:version_from_file){"4b19a96d57bff9bbf4764d7323b92a0944009b9e"}

  context "testing version overrides" do

    before :each do
      # We don't want to mess with any of this stuff for these
      # tests... we're just looking at version info right now
      Omnibus::Software.any_instance.stub(:render_tasks)
    end

    subject{software}
    
    context "without overrides" do
      let(:software){Omnibus::Software.load(software_file, project)}
        
      its(:name){should eq(software_name)}
      its(:version){should eq(version_from_file)}
      its(:given_version){should eq(software.version)}
      its(:override_version){should be_nil}      
    end

    context "with overrides" do
      let(:override_software_version){"6.6.6"}
      let(:overrides) do
        {override_software_name => override_software_version}
      end
      let(:software){Omnibus::Software.load(software_file, project, overrides)}

      context "but not for this software" do
        let(:override_software_name){"chaos_monkey"}
        
        it "really should not have any overrides for this software" do
          overrides.should_not have_key(software_name)
        end
        
        its(:version){should eq(version_from_file)}
        its(:given_version){should eq(software.version)}
        its(:override_version){should be_nil}
      end

      context "for this software" do
        let(:override_software_name){software_name}

        it "really should have an override for this software" do
          overrides.should have_key(software_name)
        end
      
        its(:version){should eq(override_software_version)}
        its(:override_version){should eq(software.version)}
        its(:version){should_not eq(software.given_version)}
        its(:given_version){should eq(version_from_file)}
      end
    end

  end
end
