require 'fluent/plugin/filter'
require 'fluent/config/error'
require 'fileutils'
require_relative 'audio_transcoder/processor'

module Fluent
  module Plugin
    class AudioTranscoderFilter < Filter
      Fluent::Plugin.register_filter('audio_transcoder', self)

      # Processing options
      desc 'Audio filter string (FFmpeg format)'
      config_param :audio_filter, :string, default: nil
      
      # Output format options
      desc 'Output format (same/mp3/aac/wav/ogg/flac)'
      config_param :output_format, :enum, list: [:same, :mp3, :aac, :wav, :ogg, :flac], default: :same
      
      desc 'Output bitrate'
      config_param :output_bitrate, :string, default: '192k'
      
      desc 'Output sample rate'
      config_param :output_sample_rate, :integer, default: 44100
      
      desc 'Output channels'
      config_param :output_channels, :integer, default: 1
      
      # Other options
      desc 'Path for temporary files'
      config_param :buffer_path, :string, default: '/tmp/fluentd-audio-transcoder'

      # Output tag (default: "transcoded." + input tag)
      desc 'Output tag'
      config_param :tag, :string

      def configure(conf)
        super
        
        # Initialize processor
        @processor = AudioTranscoder::Processor.new(
          audio_filter: @audio_filter,
          output_format: @output_format,
          output_bitrate: @output_bitrate,
          output_sample_rate: @output_sample_rate,
          output_channels: @output_channels,
          buffer_path: @buffer_path,
          log: log
        )
      end

      def start
        super
        log.info "Starting audio_transcoder filter plugin"
      end

      def shutdown
        super
        log.info "Shutting down audio_transcoder filter plugin"
        # Clean up temporary files
        @processor.cleanup if @processor
      end

      def filter(tag, time, record)
        # Validate record has either content or a valid path
        unless valid_record?(record)
          log.error "Invalid record: must have either 'content' or a valid 'path'"
          return nil
        end

        begin
          # Process the audio file
          result = @processor.process(record)
          
          if result
            # Prepare new record with processed data
            new_record = prepare_output_record(record, result)
            
            # Return the processed record
            return new_record
          else
            log.error "Failed to process audio"
            return nil
          end
        rescue => e
          log.error "Error processing audio: #{e.class} #{e.message}"
          log.error_backtrace(e.backtrace)
          return nil
        end
      end

      private

      def valid_record?(record)
        return true if record['content']
        return true if record['path'] && File.exist?(record['path'])
        false
      end



      def prepare_output_record(original_record, result)
        # Start with a new record with original_ prefix for all fields except content
        new_record = {}
        
        # First add all original fields with prefix
        original_record.each do |key, value|
          next if key == 'content' # Skip content to save space
          @tag if key == 'tag'
          new_record["original_#{key}"] = value
        end
        
        # Then add new processed data
        new_record.merge!(result)
        
        # Return the new record
        new_record
      end
    end
  end
end
