module FourGif
  module Spawn
    
    def self.call(*args)
      args = args[0] if args.count == 1
      IO.popen(args, :err=>[:child, :out]) do |io|
        output = io.read
      end
      
      puts output if $? != 0 && output.length > 0
                  
    end
    
  end
end