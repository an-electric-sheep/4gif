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
        
        ceiling = set.global_config.max_width + 1 # integer math / flooring
        floor = 0
        
        # initial value
        probe_width = (ceiling+floor)/2
        
        best_fit = [nil,0]
        
        while(true)
          
          set.generate_raws probe_width
          set.generate_color_map
          set.generate_optimized
          
          merged_name = set.merge
        
          size = File.stat(merged_name).size
          
          puts "width: #{probe_width} -> size: #{size}"
          
          if size <= MAXSIZE
            best_fit = [merged_name,probe_width] if probe_width > best_fit[1]
            floor = probe_width
          else
            ceiling = probe_width
          end
          
          # assume quadratic relation between width and file size -> try to get a better guess than the ceil+floor / 2
          # chunk target range into 10 ranges, pick the one closest to the guess
          guessed_next_target = probe_width.to_f * Math.sqrt(MAXSIZE / size.to_f)
          # floor everything to stick to the inclusive minimum, exclusive maximum logic
          # remove previous value to prevent infinite loops/early aborts
          probe_width = (1...10).map{|i| i.to_f/10 * (ceiling-floor) + floor}.map(&:floor).tap{|arr| arr.delete(probe_width)}.min_by{|i| (guessed_next_target - i).abs} || (floor+ceiling)/2
          # clamp
          probe_width = [floor,probe_width,ceiling-1].sort[1]
          
          break if probe_width <= floor

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

