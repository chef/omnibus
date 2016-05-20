module Omnibus
  class EmptyManifestDiff
    def updated
      []
    end

    def added
      []
    end

    def removed
      []
    end

    def empty?
      true
    end
  end

  class ManifestDiff
    def initialize(first, second)
      @first = first
      @second = second
    end

    def updated
      @updated ||=
        begin
          (first.entry_names & second.entry_names).collect do |name|
            diff(first.entry_for(name), second.entry_for(name))
          end.compact
        end
    end

    def removed
      @removed ||=
        begin
          (first.entry_names - second.entry_names).collect do |name|
            removed_entry(first.entry_for(name))
          end
        end
    end

    def added
      @added ||=
        begin
          (second.entry_names - first.entry_names).collect do |name|
            new_entry(second.entry_for(name))
          end
        end
    end

    def empty?
      updated.empty? && removed.empty? && added.empty?
    end

    private

    attr_reader :first, :second

    def new_entry(entry)
      { name: entry.name,
        new_version: entry.locked_version,
        source_type: entry.source_type,
        source: entry.locked_source }
    end

    def removed_entry(entry)
      { name: entry.name,
        old_version: entry.locked_version,
        source_type: entry.source_type,
        source: entry.locked_source }
    end

    def diff(a, b)
      if a == b
        nil
      else
        { name: b.name,
          old_version: a.locked_version,
          new_version: b.locked_version,
          source_type: b.source_type,
          source: b.locked_source }
      end
    end
  end
end
