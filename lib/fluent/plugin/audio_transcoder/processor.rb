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
            
            # Build the audio filter string
            audio_filter = build_audio_filter
            
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
              # Get information about the processed file
              processed_movie = FFMPEG::Movie.new(output_path)
              
              # Read the binary content
              content = nil
              File.open(output_path, 'rb') do |file|
                content = file.read
              end
              
              # Return the processed data
              {
                'path' => output_path,
                'filename' => output_filename,
                'size' => File.size(output_path),
                'format' => output_format,
                'content' => content,
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
        
        def build_audio_filter
          # If custom audio_filter is provided, use it directly
          return @options[:audio_filter] if @options[:audio_filter]
          
          filters = []
          
          # Normalization filter
          if @options[:normalize]
            filters << "loudnorm=I=#{@options[:normalize_level]}:TP=-1.5:LRA=11"
          end
          
          # Frequency filters
          case @options[:filter_type]
          when :lowpass
            filters << "lowpass=f=#{@options[:filter_frequency]}"
          when :highpass
            filters << "highpass=f=#{@options[:filter_frequency]}"
          when :bandpass
            center_freq = @options[:filter_frequency]
            filters << "bandpass=f=#{center_freq}:width_type=h:width=#{center_freq / 2}"
          end
          
          # Noise reduction
          if @options[:noise_reduction]
            # Convert the 0-1 scale to appropriate afftdn parameters
            nr_value = (@options[:noise_reduction_level] * 20).round
            nf_value = -25 - (@options[:noise_reduction_level] * 15).round
            filters << "afftdn=nr=#{nr_value}:nf=#{nf_value}"
          end
          
          # Silence trimming
          if @options[:trim_silence]
            threshold = @options[:silence_threshold]
            filters << "silenceremove=1:0:#{threshold}dB:2:0:#{threshold}dB"
          end
          
          # Combine all filters
          filters.empty? ? nil : filters.join(',')
        end
      end
    end
  end
end
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
            
            # Build the audio filter string
            audio_filter = build_audio_filter
            
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
              # Get information about the processed file
              processed_movie = FFMPEG::Movie.new(output_path)
              
              # Read the binary content
              content = nil
              File.open(output_path, 'rb') do |file|
                content = file.read
              end
              
              # Return the processed data
              {
                'path' => output_path,
                'filename' => output_filename,
                'size' => File.size(output_path),
                'format' => output_format,
                'content' => content,
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
        
        def build_audio_filter
          # If custom audio_filter is provided, use it directly
          return @options[:audio_filter] if @options[:audio_filter]
          
          filters = []
          
          # Normalization filter
          if @options[:normalize]
            filters << "loudnorm=I=#{@options[:normalize_level]}:TP=-1.5:LRA=11"
          end
          
          # Frequency filters
          case @options[:filter_type]
          when :lowpass
            filters << "lowpass=f=#{@options[:filter_frequency]}"
          when :highpass
            filters << "highpass=f=#{@options[:filter_frequency]}"
          when :bandpass
            center_freq = @options[:filter_frequency]
            filters << "bandpass=f=#{center_freq}:width_type=h:width=#{center_freq / 2}"
          end
          
          # Noise reduction
          if @options[:noise_reduction]
            # Convert the 0-1 scale to appropriate afftdn parameters
            nr_value = (@options[:noise_reduction_level] * 20).round
            nf_value = -25 - (@options[:noise_reduction_level] * 15).round
            filters << "afftdn=nr=#{nr_value}:nf=#{nf_value}"
          end
          
          # Silence trimming
          if @options[:trim_silence]
            threshold = @options[:silence_threshold]
            filters << "silenceremove=1:0:#{threshold}dB:2:0:#{threshold}dB"
          end
          
          # Combine all filters
          filters.empty? ? nil : filters.join(',')
        end
      end
    end
  end
end
