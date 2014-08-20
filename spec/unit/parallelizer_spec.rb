require 'spec_helper'
require 'thread'

module Omnibus
  describe Parallelizer do
    it 'has a class level default thread count' do
      Parallelizer.threads = 20
      threads = 0
      Parallelizer.parallel_do([2]) do |item|
        threads = Parallelizer.parallelizer.num_threads
      end
      expect(threads).to eq(20)
    end

    describe '#parallel_do(enumerable, options={}, &block)' do
      it 'itterates through an enumerable in parallel' do
        array = [1,2,3,4,5,6]
        m = Mutex.new
        Parallelizer.parallel_do(array.each_with_index) do |item, i| 
          m.synchronize { array[i] = item.to_s }
        end
        expect(array[0]).to eq("1")
      end

      it 'handles exceptions correctly' do
        array = [1,2,"3",4]
        processed = []
        m = Mutex.new
        Parallelizer.parallel_do(array.each_with_index) do |item, i| 
          m.synchronize { 
            begin
              processed << item+1 
            rescue
            end
          }
        end
        expect(processed.length).to eq(3)
      end

    end
  end
end
