require "benchmark"

module FourGif
  module Spawn

    def self.call(*args)
      args = args[0] if args.count == 1

      output = nil

      ms = Benchmark.measure do
        IO.popen(args, :err=>[:child, :out]) do |io|
          output = io.read
        end
      end.real * 1000

      #puts "#{caller[0]} -> #{ms}ms"

      if $? != 0 && output && output.length > 0
        raise output
      end

      output
    end

  end
end