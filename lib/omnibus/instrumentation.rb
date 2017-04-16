#
# Copyright 2013-2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  module Instrumentation
    include Logging

    def measure(label, &block)
      start = Time.now
      yield
    ensure
      elapsed = Time.now - start
      log.info(log_key) { "#{label}: #{elapsed.to_f.round(4)}s" }
    end

    def record_changes(label, dirs, &block)
      indexes = {}
      dirs.each do |dir|
        indexes[dir] = Index.create dir
      end
      block.call
    ensure
      log.info(log_key) { "Starting changes for #{label}" }
      indexes.each do |dir, index|
        index.changes.each do |change|
          log.info(log_key) { "#{change}" }
        end
      end
      log.info(log_key) { "Ending changes for #{label}" }
      log.info(log_key) { "--------------------------" }
    end

    class Index
      def self.create(dir)
        stats = {}
        if FileTest.exist? dir
          Dir.foreach(dir).each do |f|
            stats[f] = File::Stat.new(File.join(dir, f))
          end
        end
        Index.new(dir, stats)
      end

      def initialize(dir, stats)
        @dir = dir
        @stats = stats
      end

      def changes
        c = []
        if FileTest.exist? @dir
          files = []
          Dir.foreach(@dir) do |f|
            files << f
            prev_stat = @stats[f]
            if prev_stat
              stat = File::Stat.new(File.join(@dir, f))
              if stat.mtime != prev_stat.mtime && !stat.directory?
                c << "m #{File.join(@dir, f)}"
              end
            else
              c << "+ #{File.join(@dir, f)}"
            end
          end
          @stats.keys.reject {|x| files.include? x}.each do |deleted|
            c << "- #{File.join(@dir, deleted)}"
          end
        end
        c
      end
    end
  end
end
