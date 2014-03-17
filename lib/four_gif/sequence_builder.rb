module FourGif
  class SequenceBuilder
    
    def initialize args
      @args = args
    end
    
    def defaults
      config = OpenStruct.new
      config.fuzz = 2
      config.speed = 1.0
      config.max_width = 1280
      config.colors = 255
      config
    end
    
    def parse(arr)
      config = OpenStruct.new
      
      # dummy parser for now to get things running
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{opts.program_name} [global options]\n            FILE1 [FILE OPTIONS] START_TIMECODE END_TIMECODE [TIMESLICE OPTIONS] [START_TIMECODE END_TIMECODE [TIMESLICE OPTIONS]]\n            [FILE2 ...]"
        opts.separator ""
        opts.separator "Requirements:\n * ffmpeg\n * gifsicle\n * imagemagick\n * ruby, but you know that already\n * Several gigabytes of ram/swap/tmp space (5+GB in some cases) at higher output resolutions"
        opts.separator ""
        
        opts.on('--reverse', "reverse image sequence, useful for creating loops") do
          config.reverse = true
        end
                
        opts.on('--duration N', "duration of the last frame within a sequence in milliseconds, useful for inserting images or lingering before a cut") do |delay|
          config.last_frame_duration = delay
        end
  
        opts.on('--maxw N', OptionParser::DecimalInteger, "maximum width to search for (default: 1280)") do |c|
          config.max_width = c
        end
        
        opts.on('--crop x0,y0,x1,y1', Array, 'Crop source video to the defined rectagle. (zero offset based, full 720p rectangle -> 0,0,1279,719)') do |arr|
          config.crop_bounds = arr.map(&:to_i)
        end
        
        opts.on('--speed F', Float, 'Speed up animation by given factor (values < 1 for slowdown)') do |f|
          config.speed = f
        end
        
        opts.on( '-h', '--help', 'Display this screen' ) do
          puts opts
          exit
        end
        
        opts.separator "\nSize/Quality tradeoff options. Increases in file size are equivalent to decreases in max resolution:"
        opts.separator ""
  
              
        opts.on('--fuzz N', OptionParser::DecimalNumeric, "Set fuzz factor (see imagemagick docs) for OptimizeTransparency. default = 2. lower values may improve quality, increase file size") do |n|
          config.fuzz = n
        end
        
       
        opts.on('-d','--decimate [N]', OptionParser::DecimalInteger, "Reduce framerate by a factor of N (3 if none given). Reduces filesize. May make content more stuttery. Useful for animated content that has fewer key animation frames than video FPS") do |d|
          config.decimate = d || 3
        end
        
        opts.on('-g','--global [N]', OptionParser::DecimalInteger, "Force single global color map. Reduces file size. Good for a single scene of animated content where every frame uses a similar color palette. May lead to horrible coloring.") do |colors|
          config.colors = colors
          config.colors = 255 if colors == 0 || colors.nil?
          config.global_color_map = true
        end
               
        opts.on('--odither [pattern]', 'Enable ordered dithering. Reduces banding. Increases filesize') do |order|
          config.ordered_dither = order
        end
         
        opts.on('--dither', 'Enable dithering. Reduces banding. Increases filesize') do
          config.dither = true
        end
        
        opts.separator ""
      end
      
      parser.order! arr
      
      config
    end
    
    def build

      
      global_opts = parse @args
      
      sequences = SequenceSet.new
      sequences.global_config = OpenStruct.new(defaults.to_h.merge(global_opts.to_h))
      
      current_file = nil
      current_sequence = nil
      
      while(@args.any?)
        next_opt = @args.shift
        
        if File.exists? next_opt
          current_file = File.expand_path next_opt
          file_opts = parse @args
          sequence = nil
          
          while(@args.count >= 2 && @args[0...2].all?{|e| e[/^(\d+|\d:\d{2}:\d{2}\.\d{3})$/]})
            sequence = sequences.add(current_file)
            sequence.timestamps(@args.shift, @args.shift)
                    
            sequence_opts = parse @args
            sequence.set_opts defaults
            sequence.set_opts global_opts
            sequence.set_opts file_opts
            sequence.set_opts sequence_opts 
          end
          
          # no timestamps found?
          if sequence.nil?
            sequence = sequences.add(current_file)
                    
            sequence_opts = parse @args
            sequence.set_opts defaults
            sequence.set_opts global_opts
            sequence.set_opts file_opts
            sequence.set_opts sequence_opts          
          end
        end
        
      end
      
      sequences    
    end
    
  end
end
