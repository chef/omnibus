require "omnibus/git_repository"

module Omnibus
  class ChangeLog
    CHANGELOG_TAG = "ChangeLog-Entry".freeze

    attr_reader :end_ref
    def initialize(start_ref = nil, end_ref = "HEAD", git_repo = GitRepository.new("./"))
      @start_ref = start_ref
      @end_ref = end_ref
      @git_repo = git_repo
    end

    def authors
      git_repo.authors(start_ref, end_ref)
    end

    def changelog_entries
      entries = []
      current_entry = []
      git_repo.commit_messages(start_ref, end_ref).each do |l|
        if blank?(l)
          entries << current_entry
          current_entry = []
        elsif tagged?(l)
          entries << current_entry
          current_entry = Array(l.sub(/^#{CHANGELOG_TAG}:[\s]*/, ""))
        elsif !current_entry.empty?
          current_entry << l
        end
      end
      entries << current_entry
      entries.reject(&:empty?).map(&:join)
    end

    def start_ref
      @start_ref ||= git_repo.latest_tag
    end

    private

    attr_reader :git_repo

    def blank?(line)
      line =~ /^[\s]*$/
    end

    def tagged?(line)
      line =~ /^#{CHANGELOG_TAG}:/
    end
  end
end
