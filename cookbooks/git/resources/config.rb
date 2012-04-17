actions :set, :unset
attribute :key, :kind_of => String, :name_attribute => true
attribute :value, :kind_of => String, :default => ""
attribute :user, :kind_of => String, :default => "root"
attribute :repository, :kind_of => [String, Symbol], :default => :global

def initialize(*args)
  super
  @action = :set
end

def file_scope
  repository == :global ? "--global" : "--local"
end

def cwd
  repository == :global ? Dir.getwd : repository
end
