module FourGif
  class SequenceSet

    attr_reader :sequences
    attr_accessor :iteration, :global_config

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

    def color_map
      # only calculate global color map once from initial iteration, should be 'good enough'
      # run in background until it's needed
      @color_map ||= future do
        to_map = sequences.select{|s| s.config.global_color_map}.flat_map(&:raw_files)

        raise "too many colors" if global_config.colors > 255

        FourGif::Spawn.call "convert #{to_map.join ' '} -alpha set -treedepth 8 +depth -colorspace Lab -background none +dither +append -quantize Lab -colors #{global_config.colors} -unique-colors null: +append colors.miff" if to_map.any?

        "colors.miff"
      end
    end

    OditherStats = Struct.new(:weights, :means, :ranges, :quantumrange)

    def odither_stats
      @weights ||= future do
        to_dither = sequences.select{|s| s.requires_odither?}.flat_map(&:raw_files)

        if to_dither.any?

          #puts FourGif::Spawn.call("convert #{to_dither.join ' '} +depth -colorspace Lab -append -verbose -identify info:foo.txt")

          info = FourGif::Spawn.call("convert #{to_dither.join ' '} +depth -colorspace Lab +append -format '%[fx:standard_deviation.r] %[fx:standard_deviation.g] %[fx:standard_deviation.b]\n%[fx:mean.r] %[fx:mean.g] %[fx:mean.b]\n%[fx:minima.r] %[fx:maxima.r] %[fx:minima.g] %[fx:maxima.g] %[fx:minima.b] %[fx:maxima.b]\n%[fx:QuantumRange]' info:-")

          puts info

          raw_devs,raw_means,raw_ranges,quantum = info.split(/\n/)

          std_devs = raw_devs.split(/\s+/).map &:to_f

          # correction based on max/min a*b* values observed in a fully saturated HSL color gradient when converted to Lab
          # L* already has full 0-1 coverage and doesn't need to be normalized
          std_devs[1] /= 0.88-0.16
          std_devs[2] /= 0.87-0.07

          max = std_devs.max

          # normalize
          weights = std_devs.map{|f| f / max }

          weights = weights.map{|w| Math.sqrt w }

          puts "weights: "+weights.inspect

          OditherStats.new(weights, raw_means.split(/\s+/), raw_ranges.split(/\s+/), quantum.to_f)
        end
      end
    end


    def generate_raws(width)
      sequences.pmap{|s| s.generate_raw_images(width)}
    end


    def iterative_dithering

      odither_seqs = sequences.select(&:requires_odither?)

      return if odither_seqs.none?

      color_thresholds = odither_seqs.map{|s| s.config.colors}.uniq

      raise "inconsistent color thresholds for ordered dithers" unless color_thresholds.count == 1

      color_threshold = color_thresholds.first

      min = Math.cbrt(color_threshold).to_i
      max = 30

      sync = CyclicSynchronizer.new odither_seqs, ->(seq, &blk){seq.ordered_dither(min, max, &blk)} do |seq_files|
        colors = combined_odithered_colors(seq_files)
        puts "odithered-colors: #{colors}"
        small_enough = colors <= color_threshold
        small_enough
      end

    end


    def combined_odithered_colors(names)

      global_colors = "-append" if global_config.global_color_map

      counts = FourGif::Spawn.call("convert #{names.join(' ')} +dither -treedepth 8 -background none -alpha Background -unique-colors #{global_colors} -format '%k ' info:-")

      counts = counts.split(/\s+/).map(&:to_i)

      puts counts.inspect

      count = counts.max

      count
    end

    def generate_optimized
      sequences.pmap(&:optimize_frames)
      t1=Thread.new{ sequences.pmap(&:color_reduce) }

      iterative_dithering

      t1.join
    end


    def merge
      names = sequences.map(&:quantized).join(" ")

      FourGif::Spawn.call("convert #{names} -background none -layers RemoveZero tmp#{iteration}.gif")

      # even more optimizations
      FourGif::Spawn.call("gifsicle -w tmp#{iteration}.gif -O3 > out#{iteration}.gif")

      "out#{iteration}.gif"
    end

    def process(width)
      self.iteration += 1

      generate_raws width

      # kick off async stuff
      color_map
      odither_stats

      generate_optimized
      merge
    end

  end
end
