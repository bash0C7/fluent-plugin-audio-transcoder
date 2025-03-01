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

require 'fluent/plugin/output'
require 'fluent/config/error'
require 'streamio-ffmpeg'
require 'logger'

module Fluent
  module Plugin
    class AudioTranscoderOutput < Output
      Fluent::Plugin.register_output('audio_transcoder', self)

      helpers :event_emitter

      desc 'タグ'
      config_param :tag, :string, default: 'audio.normalized'

      desc '音声コーデック'
      config_param :audio_codec, :string, default: 'aac'

      desc '音声ビットレート'
      config_param :audio_bitrate, :string, default: '192k'

      desc '音声サンプルレート'
      config_param :audio_sample_rate, :integer, default: 44100

      desc '音声フィルター'
      config_param :audio_filter, :string, default: "loudnorm=I=-16:TP=-1.5:LRA=11," + 
                              "highpass=f=60,lowpass=f=12000," +
                              "equalizer=f=150:width_type=h:width=100:g=-8," +
                              "equalizer=f=300:width_type=h:width=100:g=2," +
                              "equalizer=f=1200:width_type=h:width=600:g=3," +
                              "equalizer=f=2500:width_type=h:width=1000:g=2," +
                              "equalizer=f=5000:width_type=h:width=1000:g=1," +
                              "afftdn=nf=-20:nr=0.5"
                              
      desc 'トランスコード後に元のファイルを削除するか'
      config_param :remove_original, :bool, default: false

      def configure(conf)
        super
        # FFMPEGが利用可能かチェック
        check_ffmpeg
      end

      def start
        super
        @logger = create_logger
      end
      
      def process(tag, es)
        es.each do |time, record|
          begin
            input_path = record['path']
            unless input_path && File.exist?(input_path)
              log.error "オーディオファイルが存在しません: #{input_path}"
              next
            end

            # オーディオファイルをトランスコード
            normalized_path = transcode_audio(input_path)
            
            if normalized_path && File.exist?(normalized_path)
              # 新しいレコードを作成して転送
              new_record = record.merge(
                'path' => normalized_path,
                'original_path' => input_path,
                'size' => File.size(normalized_path),
                'normalized' => true
              )
              
              router.emit(@tag, time, new_record)
              log.info "オーディオを正規化しました: #{input_path} -> #{normalized_path}"
              
              # 元のファイルを削除（設定されている場合）
              if @remove_original && File.exist?(input_path)
                File.unlink(input_path)
                log.info "元のオーディオファイルを削除しました: #{input_path}"
              end
            else
              log.error "オーディオ正規化に失敗しました: #{input_path}"
            end
          rescue => e
            log.error "オーディオ処理中にエラーが発生しました: #{e.class} #{e.message}"
            log.error_backtrace(e.backtrace)
          end
        end
      end

      private
      
      def create_logger
        logger = Logger.new(STDERR)
        logger.formatter = proc { |severity, datetime, progname, msg| 
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] AudioTranscoder: #{msg}\n" 
        }
        logger
      end
      
      def check_ffmpeg
        begin
          FFMPEG.ffmpeg_binary
        rescue => e
          raise Fluent::ConfigError, "FFmpegの設定に問題があります: #{e.message}"
        end
      end

      def transcode_audio(input_path)
        output_path = "#{input_path}.normalized.#{@audio_codec}"
        log.info "音声ファイルを正規化中: #{input_path} -> #{output_path}"
        
        begin
          # streamio-ffmpegを使用してトランスコード
          movie = FFMPEG::Movie.new(input_path)
          
          # トランスコードオプション
          options = {
            audio_codec: @audio_codec,
            audio_bitrate: @audio_bitrate,
            audio_sample_rate: @audio_sample_rate,
            audio_filter: @audio_filter,
            custom: %w(-y)
          }
          
          # 現在の音量レベルをログ出力
          log.info "元ファイルの情報: サイズ #{movie.size}、長さ #{movie.duration}秒、コーデック #{movie.audio_codec}"
          
          # トランスコード実行
          success = movie.transcode(output_path, options)
          
          if success
            normalized_movie = FFMPEG::Movie.new(output_path)
            log.info "正規化後ファイルの情報: サイズ #{normalized_movie.size}、長さ #{normalized_movie.duration}秒、コーデック #{normalized_movie.audio_codec}"
            return output_path
          else
            log.error "トランスコード処理が失敗しました"
            return nil
          end
        rescue => e
          log.error "トランスコード処理エラー: #{e.message}"
          log.error_backtrace(e.backtrace)
          return nil
        end
      end
    end
  end
end
