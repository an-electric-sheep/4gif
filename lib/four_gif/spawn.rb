module FourGif
  module Spawn
    
    def self.call(*args)
      args = args[0] if args.count == 1
      
      output = nil
      
      IO.popen(args, :err=>[:child, :out]) do |io|
        output = io.read
      end
      
      if $? != 0 && output && output.length > 0
        raise output
      end 
                  
    end
    
  end
end