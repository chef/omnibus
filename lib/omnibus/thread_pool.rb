require 'thread'

module Omnibus

  class ThreadPool

    attr_reader :queue, :pool, :jobs

    def initialize(poolsize)
      @queue = Queue.new
      @mutex = Mutex.new
      @jobs = 0
      @poolsize = poolsize  
      @pool = Array.new(@poolsize) do |i|
        Thread.new do
          Thread.current[:id] = i
          catch(:close) do
            loop do
              job, args = @queue.pop
              job.call(*args)
              @mutex.synchronize { @jobs -= 1 }
            end
          end
        end
      end
    end
  
    def launch(*args, &block)
      @mutex.synchronize { @jobs += 1 }
      @queue << [block, args]
    end

    def state
      @mutex.synchronize {
        if @jobs > 0
          return 'working'
        else
          return 'idle'
        end
      }
    end
  
    def stop
      @poolsize.times do
        launch { throw :close }
      end
      @pool.map(&:join)
    end
  end
end