module Omnibus
  class SemanticVersion
    def initialize(version_string)
      @has_v = !!(version_string =~ /^v/)
      @version = Gem::Version.new(version_string.gsub(/^v/, ""))
    end

    def next_patch
      major, minor, patch = @version.segments
      s = [major, minor, patch + 1].map(&:to_s).join(".")
      @has_v ? "v#{s}" : s
    end

    def next_minor
      major, minor, patch = @version.segments
      s = [major, minor + 1, patch].map(&:to_s).join(".")
      @has_v ? "v#{s}" : s
    end

    def next_major
      major, minor, patch = @version.segments
      s = [major+1, minor, patch].map(&:to_s).join(".")
      @has_v ? "v#{s}" : s
    end
  end
end
