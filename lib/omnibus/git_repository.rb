require "omnibus/util"

module Omnibus
  class GitRepository
    include Util

    def initialize(path = "./")
      @repo_path = path
    end

    def authors(start_ref, end_ref)
      formatted_log_between(start_ref, end_ref, "%aN").lines.map(&:chomp).uniq
    end

    def commit_messages(start_ref, end_ref)
      formatted_log_between(start_ref, end_ref, "%B").lines.to_a
    end

    def revision
      git("rev-parse HEAD").strip
    end

    def latest_tag
      git("describe --abbrev=0").chomp
    end

    def file_at_revision(path, revision)
      git("show #{revision}:#{path}")
    end

    private

    attr_reader :repo_path

    def formatted_log_between(start_ref, end_ref, format)
      git("log #{start_ref}..#{end_ref} --pretty=\"format:#{format}\"")
    end

    def git(cmd)
      shellout!("git #{cmd}", cwd: repo_path).stdout
    end
  end
end
