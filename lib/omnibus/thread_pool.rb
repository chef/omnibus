#
# Copyright 2014 Mike Heijmans
# Copyright 2014 Chef Software, Inc.
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

require "thread"

module Omnibus
  class ThreadPool

    #
    # Create a new thread pool of the given size. If a block is given, it is
    # assumed the thread pool is wrapping an operation and will block until all
    # operations complete.
    #
    # @example Using a block
    #   ThreadPool.new(5) do |pool|
    #     complex_things.each do |thing|
    #       pool.schedule { thing.run }
    #     end
    #   end
    #
    # @example Using the object
    #   pool = ThreadPool.new(5)
    #   # ...
    #   pool.schedule { complex_operation_1 }
    #   pool.schedule { complex_operation_2 }
    #   # ...
    #   pool.schedule { complex_operation_4 }
    #   # ...
    #   pool.shutdown
    #
    #   # or
    #
    #   at_exit { pool.shutdown }
    #
    # @param [Integer] size
    #   the number of items to put in the thread pool
    #
    def initialize(size)
      @size = size
      @jobs = Queue.new

      @pool = Array.new(@size) do |i|
        Thread.new do
          Thread.abort_on_exception = true
          Thread.current[:id] = i

          catch(:exit) do
            loop do
              job, args = @jobs.pop
              job.call(*args)
            end
          end
        end
      end

      if block_given?
        yield self
        shutdown
      end
    end

    #
    # Schedule a single item onto the queue. If arguments are given, those
    # arguments are used when calling the block in the queue. This is useful
    # if you have arguments that you need to pass in from a parent binding.
    #
    # @param [Object, Array<Object>] args
    #   the arguments to pass to the block when calling
    # @param [Proc] block
    #   the block to execute
    #
    # @return [void]
    #
    def schedule(*args, &block)
      @jobs << [block, args]
    end

    #
    # Stop the thread pool. This method quietly injects an exit clause into the
    # queue (sometimes called "poison") and then waits for all threads to
    # exit.
    #
    # @return [true]
    #
    def shutdown
      @size.times do
        schedule { throw :exit }
      end

      @pool.map(&:join)

      true
    end
  end
end
