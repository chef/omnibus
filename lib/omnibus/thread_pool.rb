require 'thread'

module Omnibus

  class ThreadPool
    def initialize(poolsize)
      @queue = Queue.new
      @poolsize = poolsize  
      @pool = Array.new(@poolsize) do |i|
        Thread.new do
          Thread.current[:id] = i
          catch(:close) do
            loop do
              job, args = @queue.pop
              job.call(*args)
            end
          end
        end
      end
    end
  
    def launch(*args, &block)
      @queue << [block, args]
    end
  
    def stop
      @poolsize.times do
        launch { throw :close }
      end
      @pool.map(&:join)
    end
  end
end