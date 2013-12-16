#! /usr/bin/ruby

require 'tmpdir'
require 'optparse'

MAXSIZE = 3*1024*1024

class GifProcessor
  
  attr_accessor :dither, :decimate, :global_color_map, :file, :timecodes, :ceiling, :fuzz, :loop
  
  def initialize
    self.ceiling = 1280
    self.fuzz = true
  end
  
  def configure(args)
    parser = OptionParser.new do|opts|
      opts.banner += " FILE START_TIMECODE END_TIMECODE [START_TIMECODE] [END_TIMECODE]  ..."
      opts.separator ""
      opts.separator "Requirements:\n * ffmpeg\n * gifsicle\n * imagemagick\n * ruby, but you know that already\n * Several gigabytes of ram/swap/tmp space (5+GB in some cases) at higher output resolutions"
      opts.separator ""
      
      opts.on('-loop', "add a reverse sequence to create a forward-rewind loop") do
        self.loop = true
      end
      
      opts.on('-pause', "extend last frame duration [not yet implemented]") do
      end

      opts.on('-maxw N', OptionParser::DecimalInteger, "maximum width to search for (default: 1280)") do |c|
        self.ceiling = c
      end
      
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
      
      opts.separator "\nSize/Quality tradeoff options. Increases in file size are equivalent to decreases in max resolution:"
      opts.separator ""

            
      opts.on('-nofuzz', "Disable approximate inter-frame color->transparencz substitution. may improve quality, increases file size") do
        self.fuzz = false
      end
      
     
      opts.on('-decimate [N]',:OPTIONAL, OptionParser::DecimalInteger, "Reduce framerate by a factor of N (3 if none given). Reduces filesize. May make content more stuttery. Useful for animated content that has fewer key animation frames than video FPS") do |d|
        self.decimate = d
      end
      
      opts.on('-global', "Force single global color map. Reduces file size. Good for a single scene of animated content where every frame uses a similar color palette. May lead to horrible coloring.") do
        self.global_color_map = true
      end
      
      opts.on('-dither', 'Enable dithering. Reduces banding. Increases filesize') do
        self.dither = true
      end
      
      opts.separator ""

    end
    
    parser.parse!(args)
    
    self.file = args.shift
    self.timecodes = args
  end
  

  def process
  
    Dir.mktmpdir do |dir|
      
     
      self.ceiling += 1 # integer math -> ceiling is never reached
      
      floor = 10 # what is this, a picture for ants?
      
      current_scale = 0  
      i = 0
      
      # last file matching size criteria and the scale used
      good = [nil,0]
      
      fps = `ffmpeg -i '#{file}' 2>&1`[/([\d.]+) fps/,1].to_f
      decimated_fps = (fps/(decimate || 1)).round

      # modified binary search for largest possible file
      while(true)
        
        current_scale = (ceiling+floor)/2
        
        break if current_scale == floor
        
        outname = "#{dir}/out#{i}.gif"
        
        framestep = "framestep=#{decimate}," if decimate
                
        # resize, decimate frame count, create PNG
        timecodes.each_slice(2).each_with_index do |(start_pos,end_pos),j|
          system("ffmpeg -v error -accurate_seek -itsoffset '#{start_pos}' -ss '#{start_pos}' -i '#{file}' -ss '#{start_pos}' -to '#{end_pos}' -filter:v hqdn3d=1.5:1.5:6:6,#{framestep}scale='#{current_scale}:-1' -f image2 #{dir}/#{j}_%04d.png")
        end
        
        files = Dir.glob("#{dir}/*.png").sort
        
        files.concat files.dup.slice(1...-1).reverse if loop
        
        files = files.join(" ")
        
        # convert to gif with various optimizations
        system("convert -delay 1x#{decimated_fps} #{files} -coalesce #{'+dither' unless dither} #{'-fuzz 2%' if fuzz} -layers OptimizePlus -layers OptimizeTransparency -layers RemoveDups -layers RemoveZero #{'+map' if global_color_map} #{dir}/tmp#{i}.gif")
        
        # files no longer needed, clean up for next interation
        system("rm #{dir}/*.png")
        
        # even more optimizations
        system("gifsicle -w #{dir}/tmp#{i}.gif -O3 > #{outname}")

        size = File.stat(outname).size
        puts "width: #{current_scale} -> size: #{size}"
        if size <= MAXSIZE
          good = [outname,current_scale] if current_scale > good[1]
          floor = current_scale
        else
          self.ceiling = current_scale
        end
        

        i += 1
      end
      
      name = "#{Time.now.to_i}.gif"
      
      system("cp #{good[0]} ./#{name}")
      
      puts name
    end
  end
end

gif = GifProcessor.new
gif.configure(ARGV)
gif.process

