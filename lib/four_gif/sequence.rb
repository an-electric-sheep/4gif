# represents an image-sequence which will be part of the final image
require 'securerandom'
require 'shellwords'
require 'ostruct'

class FourGif::Sequence
  
  attr_reader :input_file, :type, :uuid, :config, :set
  attr_accessor :start_t, :end_t, :predecessor, :fps, :optimized
  
  def initialize(set,filename)
    @set = set
    @input_file = filename
    
    IO.popen(["file", "-b", "--mime-type", filename]) do |io|
      @type = io.read
    end
    @config = OpenStruct.new
  end
  
  def timestamps s, e
    self.start_t = s
    self.end_t = e    
  end
  
  def generate_raw_images(width)
    # set new UUID as we generate new files so old ones don't carry over to new iterations
    @uuid = SecureRandom.uuid
    
    case type
    when /video/
      if config.crop_bounds
        crop_filter = "crop=#{crop_bounds[2]-crop_bounds[0]+1}:#{crop_bounds[3]-crop_bounds[1]+1}:#{crop_bounds[0]}:#{crop_bounds[1]},"
      end
      
      framestep = "framestep=#{config.decimate}," if config.decimate

      fps = `ffmpeg -i #{input_file.shellescape} 2>&1`[/([\d.]+) fps/,1].to_f

      self.fps = 1.0*fps/(config.decimate || 1)
        
      
      system("ffmpeg -v error -accurate_seek -itsoffset '#{start_t}' -ss '#{start_t}' -i #{input_file.shellescape} -ss '#{start_t}' -to '#{end_t}' -filter:v #{crop_filter}hqdn3d=1.5:1.5:6:6,#{framestep}scale='w=#{width}:h=-1:out_range=pc:flags=lanczos' -f image2 #{uuid}_%04d.png")
    when /image/
      system("convert '#{input_file}' -resize #{width} #{uuid}.png")
    else
      raise "could not detect file supported type for #{input_file.shellescape}, got '#{type}'"      
    end
  end
  
  def generate_optimized
    adjusted_fps = (fps || 24) * config.speed
    
    # add zero-delay frame from sibling sequence, required for optimal transparency optimization
    if predecessor
      initial_frame = " -delay 0 #{predecessor.files.last} "
    end
    
    # crazy mangling to allow special treatment for last frame
    delay = "-delay 1x#{adjusted_fps}"
    last_frame_delay = "-delay #{config.last_frame_duration}x1000"
    
    middle_frames = "#{delay} #{files[0...-1].join ' '}" if files.length > 1
    last_frame = "#{config.last_frame_duration ? last_frame_delay : delay} #{files.last}"
    
    name = "#{uuid}.gif"
    
    # perform opts before color mapping
    system("convert #{initial_frame} #{middle_frames} #{last_frame} -coalesce -fuzz 10% -layers RemoveDups -fuzz 0% #{'-fuzz 2%' if config.fuzz} -layers OptimizePlus -layers OptimizeTransparency #{uuid}1.miff")
    
    
    map = " -map #{set.color_map}" if config.global_color_map
    odither = "-ordered-dither #{config.ordered_dither}" if config.ordered_dither 
    
    # dither and apply color map if appropriate
    system("convert #{uuid}1.miff #{'+dither' unless config.dither} #{odither} #{map} #{name}")
        
    self.optimized = name
  end
  
  def files
    names = Dir["#{uuid}*.png"].sort
    names.reverse! if config.reverse
    names
  end
  
  def set_opts(opts)
    @config = OpenStruct.new(config.to_h.merge(opts.to_h))
  end
  
end