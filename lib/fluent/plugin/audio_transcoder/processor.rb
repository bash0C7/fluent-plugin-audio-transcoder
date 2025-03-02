require 'streamio-ffmpeg'
require 'securerandom'
require 'fileutils'
require 'pathname'
require "tempfile" 

module Fluent
  module Plugin
    module AudioTranscoder
      class Processor
        def initialize(transcode_options, output_extension, buffer_path)
          @transcode_options = transcode_options
          @output_extension = output_extension
          @buffer_path = buffer_path
        end
        
        def process(record_path, record_content)
          result = nil
          input_file = File.join(@buffer_path, File.basename(record_path))
          output_path = File.join(@buffer_path, "#{File.basename(record_path)}.#{@output_extension}")

          # Write content to the temporary file
          File.binwrite(input_file, record_content)
          # Load the movie using streamio-ffmpeg
          movie = FFMPEG::Movie.new(input_file)
          
          # Perform the transcoding
          success = movie.transcode(output_path, @transcode_options.split(' '))
          
          if success && File.exist?(output_path)
            # Clean up the output file after reading its content
            result = {
              'path' => output_path,
              'size' => File.size(output_path),
              'content' => File.binread(output_path)
            }
          else
            raise Exception.new("Transcoding failed for #{input_file}")
          end
          result
        ensure
          File.unlink(input_file) if File.exist?(input_file)
        end
      end
    end
  end
end
