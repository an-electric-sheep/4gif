# represents an image-sequence which will be part of the final image
require 'securerandom'
require 'shellwords'
require 'ostruct'

class FourGif::Sequence

  attr_reader :input_file, :type, :uuid, :config, :set
  attr_accessor :start_t, :end_t, :predecessor, :fps, :frame_optimized, :quantized

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
        crop_filter = "crop=#{config.crop_bounds[2]-config.crop_bounds[0]+1}:#{config.crop_bounds[3]-config.crop_bounds[1]+1}:#{config.crop_bounds[0]}:#{config.crop_bounds[1]},"
      end

      framestep = "framestep=#{config.decimate}," if config.decimate

      fps = `ffmpeg -i #{input_file.shellescape} 2>&1`[/([\d.]+) fps/,1].to_f

      self.fps = 1.0*fps/(config.decimate || 1)


      FourGif::Spawn.call("ffmpeg -v error -accurate_seek -itsoffset '#{start_t}' -ss '#{start_t}' -i #{input_file.shellescape} -ss '#{start_t}' -to '#{end_t}' -filter:v #{crop_filter}hqdn3d=1.5:1.5:6:6,#{framestep}scale='w=#{width}:h=-1:out_range=pc:flags=lanczos' -f image2 #{uuid}_%04d.pnm")
    when /image/
      FourGif::Spawn.call("convert '#{input_file}' -resize #{width} #{uuid}.pnm")
    else
      raise "could not detect a supported file type for #{input_file.shellescape}, got '#{type}'"
    end
  end


  def raw_files
    raise "raw files need to be generated first" unless uuid

    names = Dir["#{uuid}*.pnm"].sort
    names.reverse! if config.reverse
    names
  end

  def optimize_frames
    adjusted_fps = (fps || 24) * config.speed

    # add zero-delay frame from sibling sequence, for better transparency delta optimization
    if predecessor
      initial_frame = " -delay 0 #{predecessor.raw_files.last} "
    end

    # crazy mangling to allow special treatment for last frame
    delay = "-delay 1x#{adjusted_fps.round}"
    last_frame_delay = "-delay #{config.last_frame_duration}x1000"

    middle_frames = raw_files[0...-1].map{|f| "#{delay} #{f}"}.join(' ') if raw_files.length > 1
    last_frame = "#{config.last_frame_duration ? last_frame_delay : delay} #{raw_files.last}"

    outfile = "#{uuid}_frames.miff"

    fuzz = config.fuzz ? "-fuzz #{config.fuzz}%" : '-fuzz 2%'

    # perform opts before color mapping
    FourGif::Spawn.call("convert #{initial_frame} #{middle_frames} #{last_frame} miff:- | convert miff:- -alpha set -treedepth 8 +depth -colorspace Lab -coalesce #{fuzz} -layers OptimizePlus -layers OptimizeTransparency #{outfile}")

    self.frame_optimized = outfile
  end


  def color_reduce
    return nil if requires_odither?

    map = " -remap #{set.color_map}" if config.global_color_map
    dither = config.dither ? "-dither FloydSteinberg" : "+dither"



    outname = "#{uuid}_dithered.gif"

    # dither and apply color map if appropriate
    FourGif::Spawn.call("convert #{frame_optimized} +depth -treedepth 8 -background none -alpha Background -quantize Lab #{dither} #{map} miff:- | convert -treedepth 8 -quantize Lab miff:- #{outname}")

    self.quantized = outname
  end

  def requires_odither?
    !!config.ordered_dither
  end

  def ordered_dither(min_level, max_level, &evaluator)
    return nil unless requires_odither?

    return nil if min_level == max_level


    current_level = ((min_level+max_level)/2).floor

    stats = set.odither_stats

    levels = stats.weights.map do |w|
      l = (w*current_level).round
    end.map{|l| [2,l].max}.join(',')


    puts "levels: #{levels}"

    attempt = "#{uuid}_#{levels}_ordered.gif"

    (rmin,rmax,gmin,gmax,bmin,bmax) = stats.ranges.map(&:to_f)

    ranges = stats.ranges.map(&:to_f)


    transform_forward  = "-level-colors 'cielab(#{rmin*100}%,#{gmin*100}%,#{bmin*100}%),cielab(#{rmax*100}%,#{gmax*100}%,#{bmax*100}%)'" # %w(R G B).each_with_index.map{|c,i| "-channel #{c} -function polynomial '#{(1.0/(ranges[i*2 +1] - ranges[i*2])).round(5)}, -#{ranges[i*2]}'" }.join(" ") # "-channel R -evaluate Subtract #{rmin*100}% -evaluate Divide #{rmax-rmin} -channel G -evaluate Subtract #{gmin*100}% -evaluate Divide #{gmax-gmin} -channel B -evaluate Subtract #{bmin*100}% -evaluate Divide #{bmax-bmin}"
    transform_backward = "+level-colors 'cielab(#{rmin*100}%,#{gmin*100}%,#{bmin*100}%),cielab(#{rmax*100}%,#{gmax*100}%,#{bmax*100}%)'" #%w(R G B).each_with_index.map{|c,i| "-channel #{c} -function polynomial    '#{(ranges[i*2 +1] - ranges[i*2]).round(5)}, #{ranges[i*2]}'" }.join(" ") # "-channel R -evaluate Multiply #{rmax-rmin} -evaluate Add #{rmin*100}% -channel G -evaluate Multiply #{gmax-gmin} -evaluate Add #{gmin*100}% -channel B -evaluate Multiply #{bmax-bmin} -evaluate Add #{bmin*100}%"

    FourGif::Spawn.call("convert #{frame_optimized} -colorspace Lab +depth +dither -treedepth 8 -background none -alpha Background -quantize Lab #{transform_forward} -channel RGB -ordered-dither #{config.ordered_dither},#{levels} #{transform_backward} -channel RGBA -alpha set -colorspace sRGB #{attempt}")

    small_enough = evaluator.call(attempt)

    # out of range, try to search the bottom half unless we're a leaf node
    outname = ordered_dither(min_level, current_level, &evaluator) if current_level > min_level && !small_enough
    # try to find a better one still within the upper half
    outname = ordered_dither(current_level+1, max_level, &evaluator) if max_level > current_level+1 && small_enough

    # pass result up the tree if it's good enough and we didn't find anything better
    outname ||= attempt if small_enough

    self.quantized = outname
  end


  def set_opts(opts)
    @config = OpenStruct.new(config.to_h.merge(opts.to_h))
  end

end