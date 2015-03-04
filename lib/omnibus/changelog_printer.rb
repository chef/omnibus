module Omnibus
  class ChangeLogPrinter

    def initialize(changelog, diff)
      @changelog = changelog
      @diff = diff
    end

    def print(new_version)
      puts "## #{new_version} (#{Time.now.strftime('%Y-%m-%d')})"
      print_changelog
      if !diff.empty?
        print_components
        puts ""
      end
      print_contributors
    end

    private
    attr_reader :changelog, :diff

    def print_changelog(cl=changelog, indent=0)
      cl.changelog_entries.each do |entry|
        puts "#{' ' * indent}* #{entry.sub("\n", "\n  #{' ' * indent}")}\n"
      end
    end

    def print_components
      puts "### Components\n"
      print_new_components
      print_updated_components
      print_removed_components
    end

    def print_new_components
      puts "New Components"
      diff.added.each do |entry|
        puts "* #{entry[:name]} (#{entry[:new_version]})"
      end
      puts ""
    end

    def print_updated_components
      puts "Updated Components"
      diff.updated.each do |entry|
        puts "* #{entry[:name]} (#{entry[:old_version]} -> #{entry[:new_version]})"
      end
      puts ""
    end

    def print_removed_components
      puts "Removed Components"
      diff.removed.each do |entry|
        puts "* #{entry[:name]} (#{entry[:old_version]})"
      end
      puts ""
    end


    def print_contributors
      puts "### Contributors\n"
      changelog.authors.each do |author|
        puts "* #{author}"
      end
    end
  end
end
