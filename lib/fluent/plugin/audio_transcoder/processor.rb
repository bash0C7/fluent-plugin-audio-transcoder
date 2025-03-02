require 'streamio-ffmpeg'
require 'securerandom'
require 'fileutils'
require 'pathname'

module Fluent
  module Plugin
    module AudioTranscoder
      class Processor
        def initialize(options = {})
          @options = options
          @log = options[:log] || Logger.new(STDERR)
          
          # Ensure buffer path exists
          FileUtils.mkdir_p(@options[:buffer_path]) unless Dir.exist?(@options[:buffer_path])
          
          # Track temporary files for cleanup
          @temp_files = []
        end
        
        def process(record)
          input_path = record['path']
          
          # Generate a unique name for the processed file
          input_filename = File.basename(input_path)
          input_ext = File.extname(input_path)
          output_format = determine_output_format(input_path)
          output_filename = "processed_#{input_filename.gsub(input_ext, '')}.#{output_format}"
          output_path = File.join(@options[:buffer_path], output_filename)
          
          # Register the output file for cleanup
          @temp_files << output_path
          
          @log.info "Processing audio file: #{input_path} -> #{output_path}"
          
          begin
            # Load the movie using streamio-ffmpeg
            movie = FFMPEG::Movie.new(input_path)
            
            # Get the audio filter string directly from options
            audio_filter = @options[:audio_filter]
            
            # Determine output codec
            output_codec = determine_output_codec(output_format)
            
            # Transcoding options
            options = {
              audio_codec: output_codec,
              audio_bitrate: @options[:output_bitrate],
              audio_sample_rate: @options[:output_sample_rate],
              audio_channels: @options[:output_channels],
              custom: %w(-y)  # Overwrite output files without asking
            }
            
            # Add audio filter if specified
            options[:audio_filter] = audio_filter if audio_filter
            
            @log.debug "Transcoding with options: #{options.inspect}"
            
            # Perform the transcoding
            success = movie.transcode(output_path, options)
            
            if success && File.exist?(output_path)
              # Return the processed data
              {
                'path' => output_path,
                'filename' => output_filename,
                'size' => File.size(output_path),
                'format' => output_format,
                'content' => File.binread(output_path),
                'processing' => {
                  'audio_filter' => audio_filter,
                  'audio_codec' => output_codec,
                  'audio_bitrate' => @options[:output_bitrate],
                  'audio_sample_rate' => @options[:output_sample_rate],
                  'audio_channels' => @options[:output_channels]
                }
              }
            else
              @log.error "Transcoding failed for #{input_path}"
              nil
            end
          rescue => e
            @log.error "Error processing #{input_path}: #{e.message}"
            @log.error e.backtrace.join("\n")
            nil
          end
        end
        
        def cleanup
          @temp_files.each do |file|
            if File.exist?(file)
              @log.debug "Cleaning up temporary file: #{file}"
              File.unlink(file) rescue nil
            end
          end
        end
        
        private
        
        def determine_output_format(input_path)
          return File.extname(input_path).delete('.') if @options[:output_format] == :same
          @options[:output_format].to_s
        end
        
        def determine_output_codec(format)
          case format.to_sym
          when :mp3
            'libmp3lame'
          when :aac
            'aac'
          when :ogg
            'libvorbis'
          when :flac
            'flac'
          when :wav
            'pcm_s16le'
          else
            'aac'  # Default to AAC
          end
        end
      end
    end
  end
end
