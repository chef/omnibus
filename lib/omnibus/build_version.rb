module Omnibus
  module BuildVersion

    def self.full
      build_version
    end

    def self.version_tag
      major, minor, patch = version_composition
      "#{major}.#{minor}.#{patch}"
    end

    def self.git_sha
      sha_regexp = /g([0-9a-f]+)$/
      match = sha_regexp.match(build_version)
      match ? match[1] : nil
    end

    def self.commits_since_tag
      commits_regexp = /^\d+\.\d+\.\d+\-(\d+)\-g[0-9a-f]+$/
      match = commits_regexp.match(build_version)
      match ? match[1].to_i : 0
    end

    def self.development_version?
      major, minor, patch = version_composition
      patch.to_i.odd?
    end

    private

    def self.build_version
      @build_version ||= begin
                           git_cmd = "git describe"
                           shell = Mixlib::ShellOut.new(git_cmd,
                                                        :cwd => Omnibus.root)
                           shell.run_command
                           shell.error!
                           shell.stdout.chomp
                         end
    end

    def self.version_composition
      version_regexp = /^(\d+)\.(\d+)\.(\d+)/
      version_regexp.match(build_version)[1..3]
    end

  end
end
