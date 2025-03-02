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
        end
        
        def process(record)
          input_file = nil
          output_path = nil
          
          begin
            # Create temporary input file from content if available
            input_file = create_temp_input_file(record)
            return nil unless input_file
            
            # Keep original filename but update extension if format changes
            input_filename = record['filename'] || File.basename(input_file)
            input_ext = File.extname(input_filename)
            output_format = @options[:output_format]
            
            # Generate the output filename with the same name but potentially different extension
            output_filename = input_filename
            if @options[:output_format] != :same
              # Replace the extension only if format is changing
              output_filename = input_filename.gsub(/#{input_ext}$/, ".#{output_format}")
              output_format = (record['format'] || File.extname(input_file).delete('.')).to_sym
            end
            
            output_path = File.join(@options[:buffer_path], output_filename)
            
            @log.info "Processing audio file: #{input_file} -> #{output_path}"
            
            # Load the movie using streamio-ffmpeg
            movie = FFMPEG::Movie.new(input_file)
            
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
              # Read the processed content
              output_content = File.binread(output_path)
              output_size = File.size(output_path)
              
              # Clean up the input temporary file immediately if it's not the original path
              cleanup_temp_file(input_file) if input_file != record['path']
              
              # Clean up the output file after reading its content
              result = {
                'path' => output_path,
                'filename' => output_filename,
                'size' => output_size,
                'format' => output_format,
                'content' => output_content,
                'processing' => {
                  'audio_filter' => audio_filter,
                  'audio_codec' => output_codec,
                  'audio_bitrate' => @options[:output_bitrate],
                  'audio_sample_rate' => @options[:output_sample_rate],
                  'audio_channels' => @options[:output_channels]
                }
              }
              
              # Clean up output temporary file immediately after reading its content
              cleanup_temp_file(output_path)
              
              return result
            else
              @log.error "Transcoding failed for #{input_file}"
              # Clean up temp files on failure
              cleanup_temp_file(input_file) if input_file != record['path']
              cleanup_temp_file(output_path) if output_path && File.exist?(output_path)
              return nil
            end
          rescue => e
            @log.error "Error processing audio: #{e.message}"
            @log.error e.backtrace.join("\n")
            # Clean up temp files on error
            cleanup_temp_file(input_file) if input_file && input_file != record['path']
            cleanup_temp_file(output_path) if output_path && File.exist?(output_path)
            return nil
          end
        end
        
        private
        
        def create_temp_input_file(record)
          # If content is available, write it to a temporary file
          if record['content']
            # Use record's filename if available, otherwise generate a random name
            filename = record['filename'] || "temp_audio_#{SecureRandom.uuid}"
            temp_path = File.join(@options[:buffer_path], filename)
            
            @log.debug "Creating temporary file from content: #{temp_path}"
            
            # Write content to the temporary file
            File.binwrite(temp_path, record['content'])
            
            return temp_path
          elsif record['path'] && File.exist?(record['path'])
            # If no content but path exists, use that path
            return record['path']
          else
            @log.error "No valid content or path found in record"
            return nil
          end
        end
        
        def cleanup_temp_file(file)
          if file && File.exist?(file)
            @log.debug "Cleaning up temporary file: #{file}"
            begin
              File.unlink(file)
              @log.debug "Successfully deleted file: #{file}"
            rescue => e
              @log.error "Failed to delete file #{file}: #{e.message}"
            end
          end
        end
        
        def determine_output_format(input_format)
          return input_format if @options[:output_format] == :same
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