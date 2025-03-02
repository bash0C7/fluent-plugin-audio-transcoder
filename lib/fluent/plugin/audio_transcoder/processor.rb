require 'streamio-ffmpeg'
require 'fileutils'

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
          input_file = File.join(@buffer_path, File.basename(record_path))
          output_path = File.join(@buffer_path, "#{File.basename(record_path)}.#{@output_extension}")

          # Write content to temporary file
          File.binwrite(input_file, record_content)
          
          # Transcode the audio file
          movie = FFMPEG::Movie.new(input_file)
          options = @transcode_options.split(' ')
          success = movie.transcode(output_path, options)
          
          unless success && File.exist?(output_path)
            raise "Transcoding failed for #{input_file}"
          end
          
          {
            'path' => output_path,
            'size' => File.size(output_path),
            'content' => File.binread(output_path)
          }
        ensure
          # Clean up temporary input file
          File.unlink(input_file) if File.exist?(input_file)
        end
      end
    end
  end
end
