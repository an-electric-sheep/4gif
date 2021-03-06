#! /usr/bin/rbx

require 'tmpdir'
require 'optparse'

require_relative "lib/core_ext/concurrency"

module FourGif
  require_relative 'lib/four_gif/spawn'
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

          merged_name = set.process(probe_width)

          size = File.stat(merged_name).size

          puts "width: #{probe_width} -> size: #{size}"

          if size <= MAXSIZE
            best_fit = [merged_name,probe_width] if probe_width > best_fit[1]
            floor = probe_width
          else
            ceiling = probe_width
          end

          # assume quadratic relation between width and file size -> try to get a better guess than the ceil+floor / 2
          guessed_next_target = (probe_width.to_f * Math.sqrt(MAXSIZE / size.to_f)).to_i

          # remove previous value to prevent infinite loops/early aborts
          next_target = guessed_next_target != probe_width ? guessed_next_target : (floor+ceiling)/2

          # clamp
          next_target = [floor,next_target,ceiling-1].sort[1]

          break if next_target <= floor

          puts "next: #{next_target} prev: #{probe_width}"

          probe_width = next_target

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

