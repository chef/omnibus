require "rspec/expectations"

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

# expect('/path/to/file').to have_content
RSpec::Matchers.define :have_content do |content|
  match do |actual|
    IO.read(actual) == content
  end
end

# expect('/path/to/file').to have_permissions
RSpec::Matchers.define :have_permissions do |perm|
  match do |actual|
    m = sprintf("%o", File.stat(actual).mode)
    m == perm
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

# expect('/path/to/file').to be_an_executable
RSpec::Matchers.define :be_an_executable do
  match do |actual|
    File.executable?(actual)
  end
end

# expect('/path/to/file').to be_a_hardlink
RSpec::Matchers.define :be_a_hardlink do |path|
  match do |actual|
    File.stat(actual).nlink > 2
  end
end
