require 'rspec/expectations'

# expect('/path/to/directory').to be_a_directory
RSpec::Matchers.define :be_a_directory do
  match do |actual|
    File.directory?(actual)
  end
end

# expect('/path/to/directory').to be_a_file
RSpec::Matchers.define :be_a_file do
  match do |actual|
    File.file?(actual)
  end
end

# expect('/path/to/directory').to be_a_symlink
RSpec::Matchers.define :be_a_symlink do
  match do |actual|
    File.symlink?(actual)
  end
end

# expect('/path/to/directory').to be_a_symlink_to
RSpec::Matchers.define :be_a_symlink_to do |path|
  match do |actual|
    File.symlink?(actual) && File.readlink(actual) == path
  end
end

# expect('/path/to/directory').to be_a_symlink
RSpec::Matchers.define :be_a_symlink do
  match do |actual|
    File.symlink?(actual)
  end
end
