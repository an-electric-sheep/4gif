class FourGif::Options
  attr_accessor :dither, :decimate, :global_color_map, :file, :timecodes, :ceiling, :fuzz, :loop, :crop_bounds, :speed
  
  def initialize
    self.ceiling = 1280
    self.fuzz = true
    self.speed = 1
  end
  
  def configure(args)
    parser = OptionParser.new do|opts|
      opts.banner += " FILE START_TIMECODE END_TIMECODE [START_TIMECODE] [END_TIMECODE]  ..."
      opts.separator ""
      opts.separator "Requirements:\n * ffmpeg\n * gifsicle\n * imagemagick\n * ruby, but you know that already\n * Several gigabytes of ram/swap/tmp space (5+GB in some cases) at higher output resolutions"
      opts.separator ""
      
      opts.on('-l','--loop', "create a forward-rewind loop") do
        self.loop = true
      end
      
      opts.on('--pause', "extend last frame duration [not yet implemented]") do
      end

      opts.on('--maxw N', OptionParser::DecimalInteger, "maximum width to search for (default: 1280)") do |c|
        self.ceiling = c
      end
      
      opts.on('--crop x0,y0,x1,y1', Array, 'Crop source video to the defined rectagle. (zero offset based, full 720p rectangle -> 0,0,1279,719)') do |arr|
        self.crop_bounds = arr.map(&:to_i)
      end
      
      opts.on('--speed F', Float, 'Speed up animation by given factor (values < 1 for slowdown)') do |f|
        self.speed = f
      end
      
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
      
      opts.separator "\nSize/Quality tradeoff options. Increases in file size are equivalent to decreases in max resolution:"
      opts.separator ""

            
      opts.on('--nofuzz', "Disable approximate inter-frame color->transparency substitution. may improve quality, increases file size") do
        self.fuzz = false
      end
      
     
      opts.on('-d','--decimate [N]', OptionParser::DecimalInteger, "Reduce framerate by a factor of N (3 if none given). Reduces filesize. May make content more stuttery. Useful for animated content that has fewer key animation frames than video FPS") do |d|
        self.decimate = d || 3
      end
      
      opts.on('-g','--global', "Force single global color map. Reduces file size. Good for a single scene of animated content where every frame uses a similar color palette. May lead to horrible coloring.") do
        self.global_color_map = true
      end
      
      opts.on('--dither', 'Enable dithering. Reduces banding. Increases filesize') do
        self.dither = true
      end
      
      opts.separator ""

    end
    
    parser.parse!(args)
    
    self.file = args.shift
    self.timecodes = args
  end
end