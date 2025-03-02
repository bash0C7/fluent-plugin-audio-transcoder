#
# Copyright 2025- bash0C7
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/filter'
require 'fluent/config/error'
require 'fileutils'
require_relative 'audio_transcoder/processor'

module Fluent
  module Plugin
    class AudioTranscoderFilter < Filter
      Fluent::Plugin.register_filter('audio_transcoder', self)

      # Processing options
      desc 'Enable volume normalization'
      config_param :normalize, :bool, default: true
      
      desc 'Target normalization level in dB'
      config_param :normalize_level, :integer, default: -16
      
      desc 'Enable noise reduction'
      config_param :noise_reduction, :bool, default: true
      
      desc 'Noise reduction level (0.0 to 1.0)'
      config_param :noise_reduction_level, :float, default: 0.21
      
      desc 'Filter type (none/lowpass/highpass/bandpass)'
      config_param :filter_type, :enum, list: [:none, :lowpass, :highpass, :bandpass], default: :none
      
      desc 'Filter frequency in Hz'
      config_param :filter_frequency, :integer, default: 1000
      
      desc 'Enable silence trimming'
      config_param :trim_silence, :bool, default: true
      
      desc 'Silence threshold in dB'
      config_param :silence_threshold, :integer, default: -60
      
      # Output format options
      desc 'Output format (same/mp3/aac/wav/ogg/flac)'
      config_param :output_format, :enum, list: [:same, :mp3, :aac, :wav, :ogg, :flac], default: :same
      
      desc 'Output bitrate'
      config_param :output_bitrate, :string, default: '192k'
      
      desc 'Output sample rate'
      config_param :output_sample_rate, :integer, default: 44100
      
      desc 'Output channels'
      config_param :output_channels, :integer, default: 1
      
      # Custom audio filter (takes precedence over individual options if specified)
      desc 'Custom audio filter string (FFmpeg format)'
      config_param :audio_filter, :string, default: nil
      
      # Other options
      desc 'Path for temporary files'
      config_param :buffer_path, :string, default: '/tmp/fluentd-audio-transcoder'
      
      # Output tag (default: "transcoded." + input tag)
      desc 'Output tag'
      config_param :tag, :string, default: nil

      def configure(conf)
        super
        
        # Create buffer directory if it doesn't exist
        FileUtils.mkdir_p(@buffer_path) unless Dir.exist?(@buffer_path)
        
        # Check if FFmpeg is available
        check_ffmpeg_availability
        
        # Initialize processor
        @processor = AudioTranscoder::Processor.new(
          normalize: @normalize,
          normalize_level: @normalize_level,
          noise_reduction: @noise_reduction,
          noise_reduction_level: @noise_reduction_level,
          filter_type: @filter_type,
          filter_frequency: @filter_frequency,
          trim_silence: @trim_silence,
          silence_threshold: @silence_threshold,
          output_format: @output_format,
          output_bitrate: @output_bitrate,
          output_sample_rate: @output_sample_rate,
          output_channels: @output_channels,
          audio_filter: @audio_filter,
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
        input_path = record['path']
        unless input_path && File.exist?(input_path)
          log.error "Audio file does not exist: #{input_path}"
          return nil
        end

        # Determine output tag if not specified
        output_tag = @tag || "transcoded.#{tag}"

        begin
          # Process the audio file
          result = @processor.process(record)
          
          if result
            # Prepare new record with processed data
            new_record = prepare_output_record(record, result)
            
            # Generate new event with processed data
            router.emit(output_tag, time, new_record)
            
            # Return nil since we're manually emitting the event
            return nil
          else
            log.error "Failed to process audio file: #{input_path}"
            return nil
          end
        rescue => e
          log.error "Error processing audio: #{e.class} #{e.message}"
          log.error_backtrace(e.backtrace)
          return nil
        end
      end

      private

      def check_ffmpeg_availability
        begin
          require 'streamio-ffmpeg'
          FFMPEG.ffmpeg_binary
        rescue LoadError
          raise Fluent::ConfigError, "streamio-ffmpeg gem is not installed"
        rescue => e
          raise Fluent::ConfigError, "FFmpeg configuration error: #{e.message}"
        end
      end

      def prepare_output_record(original_record, result)
        # Start with a new record with original_ prefix for all fields except content
        new_record = {}
        
        # First add all original fields with prefix
        original_record.each do |key, value|
          next if key == 'content' # Skip content to save space
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
