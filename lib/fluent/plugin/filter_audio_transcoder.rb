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
        
        # Create buffer directory if it doesn't exist
        FileUtils.mkdir_p(@buffer_path) unless Dir.exist?(@buffer_path)
        
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
          # Process the audio file
          result = @processor.process(record)
          
          # Use the actual transcoded file path
          record["path"] = result['path'],
          # Use the size of the transcoded file
          record["size"] = result['size'],
          # Use the format used during transcoding
          record["format"] = result['format'],
          # Include the transcoded binary content
          record["content"] = result['content']
  
          record
      end

    end
  end
end
