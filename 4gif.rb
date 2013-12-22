#! /usr/bin/ruby

require 'tmpdir'
require 'optparse'

module FourGif
  require_relative 'lib/four_gif/sequence_builder'
  require_relative 'lib/four_gif/sequence_set'
  require_relative 'lib/four_gif/sequence'
end


MAXSIZE = 3*1024*1024



class GifProcessor
  
  def process(args)
    
    builder = FourGif::SequenceBuilder.new(args)
    set = builder.build
    
    working_dir = Dir.getwd
  
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        
        target_width = nil
        ceiling = set.global_config.max_width + 1 # integer math, will always round down
        floor = 10
        
        best_fit = [nil,0]
        
        while(true)
          target_width = (ceiling+floor)/2
          
          break if target_width == floor
          
          set.generate_raws(target_width)
          set.generate_global_color_map
          set.generate_optimized
          
          merged_name = set.merge
        
          size = File.stat(merged_name).size
          
          puts "width: #{target_width} -> size: #{size}"
          
          if size <= MAXSIZE
            best_fit = [merged_name,target_width] if target_width > best_fit[1]
            floor = target_width
          else
            ceiling = target_width
          end
        
        end
        
        name = "#{Time.now.to_i}.gif"
        
        system("cp #{best_fit[0]} #{File.join(working_dir,name)}")
        
        puts name  
        puts "\n"
      end
    end
  end
end

gif = GifProcessor.new
gif.process ARGV

