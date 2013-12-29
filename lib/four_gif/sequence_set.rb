module FourGif
  class SequenceSet
    
    attr_reader :sequences
    attr_accessor :iteration, :files, :global_config
    
    def initialize
      @sequences = []
      self.iteration = 0
    end
    
    def add(file)
      seq = Sequence.new(self,file)
      seq.predecessor = sequences.last
      sequences << seq
      seq 
    end
    
    def generate_raws(width)
      sequences.map{|s| Thread.new{s.generate_raw_images(width)}}.each{|t| t.join}
    end
    
    def generate_color_map
      # only calculate global color map once from initial iteration, should be 'good enough'
      # run in background until it's needed
      @map_worker ||= Thread.new do
        to_map = sequences.select{|s| s.config.global_color_map}.flat_map(&:files)
        
        FourGif::Spawn.call "convert #{to_map.join ' '} -background none +append -quantize transparent -colors #{global_config.colors} -unique-colors colors.gif" if to_map.any?
      
        "colors.gif"
      end
    end
    
    def color_map
      generate_color_map.value
    end
    
    def generate_optimized
      sequences.map{|s| Thread.new{ s.generate_optimized}}.each{|t| t.join}
      self.files = sequences.map &:optimized
    end
    
    
    def merge
      self.iteration += 1
      
      FourGif::Spawn.call("convert #{files.join(' ')} -layers RemoveDups -layers RemoveZero tmp#{iteration}.gif")
      
      # even more optimizations
      FourGif::Spawn.call("gifsicle -w tmp#{iteration}.gif -O3 > out#{iteration}.gif")
      
      "out#{iteration}.gif"
    end
    
    def process(width)
      sequences.each{|s| s.generate_raw_images(width)}
      generate_color_map
      generate_subsequences
      merge
    end
  end  
end
