require 'fluent/plugin/filter'
require 'fluent/config/error'
require_relative 'audio_transcoder/processor'

module Fluent
  module Plugin
    class AudioTranscoderFilter < Filter
      Fluent::Plugin.register_filter('audio_transcoder', self)

      desc 'Transcode options for FFmpeg including filters'
      config_param :transcode_options, :string, default: '-c:v copy -af loudnorm=I=-14:TP=0.0:print_format=summary'
      
      desc 'Output file extension'
      config_param :output_extension, :string, default: 'aac'
      
      desc 'Path for temporary files'
      config_param :buffer_path, :string, default: '/tmp/fluentd-audio-transcoder'

      def configure(conf)
        super
        @processor = AudioTranscoder::Processor.new(@transcode_options, @output_extension, @buffer_path)
      end

      def filter(tag, time, record)
        result = @processor.process(record['path'], record['content'])

        record["path"] = result['path']
        record["size"] = result['size']
        record["content"] = result['content']

        record
      end
    end
  end
end