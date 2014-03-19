require 'omnibus/project'
require 'omnibus/software'

require 'spec_helper'

describe Omnibus::Software do
  it 'includes the Chef Sugar DSL methods' do
    expect(described_class).to be_method_defined(:windows?)
    expect(described_class).to be_method_defined(:vagrant?)
    expect(described_class).to be_method_defined(:_64_bit?)
  end
end

describe Omnibus::Project do
  it 'includes the Chef Sugar DSL methods' do
    expect(described_class).to be_method_defined(:windows?)
    expect(described_class).to be_method_defined(:vagrant?)
    expect(described_class).to be_method_defined(:_64_bit?)
  end
end
