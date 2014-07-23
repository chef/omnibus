# Shell script written in Ruby to prepare Omnibus in S3 for the redirect links
# Copyright 2011, Opscode, Inc.
# Bryan McLellan <btm@loftninjas.org> 2011-12-14
require 'rubygems'
require 'right_aws'

revision = "10.16.4-1"

# This ACL is FullControl for the owner (Opscode) and Read for all others
public_acl = '<AccessControlPolicy xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Owner><ID>145c450e70dfcb6eb2f2a7e4334a6576011830b3ced4eeeb20de547653a455b3</ID><DisplayName>th416</DisplayName></Owner><AccessControlList><Grant><Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="CanonicalUser"><ID>145c450e70dfcb6eb2f2a7e4334a6576011830b3ced4eeeb20de547653a455b3</ID><DisplayName>th416</DisplayName></Grantee><Permission>FULL_CONTROL</Permission></Grant><Grant><Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="Group"><URI>http://acs.amazonaws.com/groups/global/AllUsers</URI></Grantee><Permission>READ</Permission></Grant></AccessControlList></AccessControlPolicy>'

desc "Upload install.sh to S3 and configure"
task :upload_installer, :aws_id, :aws_key, :aws_bucket do |t,args|

  puts "Creating connection"
  s3 = RightAws::S3Interface.new(args.aws_id, args.aws_key)

  puts "Uploading install.sh"
  s3.put(args.aws_bucket, 'install.sh', File.open("source/install.sh"))

  # Set the ACL; although we should not need to after the first time.
  puts "Setting ACL on install.sh"
  s3.put_acl(args.aws_bucket, 'install.sh', public_acl)
  puts "Done"
end

desc "Create chef-client-latest.msi from latest version"
task :windows_latest, :aws_id, :aws_key, :aws_bucket do |t,args|

  puts "Creating connection"
  s3 = RightAws::S3Interface.new(args.aws_id, args.aws_key)

  puts "copying windows/chef-client-#{revision}.msi to windows/chef-client-latest.msi"
  s3.copy(args.aws_bucket, "windows/chef-client-#{revision}.msi", args.aws_bucket, "windows/chef-client-latest.msi")

  # Set the ACL; although we should not need to after the first time.
  puts "Setting ACL on windows/chef-client-latest.msi"
  s3.put_acl(args.aws_bucket, 'windows/chef-client-latest.msi', public_acl)
  puts "Done"
end

desc "Update Omnibus / Chef versions"
task :update_version do

  files = [
    'config/projects/chef-full.clj',
    'config/projects/chef-server-full.clj',
    'config/software/chef.clj',
    'build-omnibus.ps1',
    'source/install.sh',
    'Rakefile'
  ]

  # use vim because we're not masochists -- btm
  files.each do |file|
    system "vim #{file}"
  end
end



