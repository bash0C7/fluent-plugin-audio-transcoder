# fluent-plugin-audio-transcoder

[Fluentd](https://fluentd.org/) plugin for audio transcoding and processing.

This plugin processes audio files by applying various filters such as normalization, noise reduction, and format conversion, optimized for speech-to-text processing.

## Installation

### RubyGems

```
$ gem install fluent-plugin-audio-transcoder
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-audio-transcoder"
```

And then execute:

```
$ bundle
```

## Configuration

### Filter Plugin Mode

```
<filter audio.recording>
  @type audio_transcoder
  
  # Processing options (all optional)
  normalize true                  # Enable/disable volume normalization
  normalize_level -16             # Target normalization level (dB)
  
  noise_reduction true            # Enable/disable noise reduction
  noise_reduction_level 0.21      # Noise reduction strength (0.0 to 1.0)
  
  filter_type none                # Filter type (none/lowpass/highpass/bandpass)
  filter_frequency 1000           # Filter frequency (Hz)
  
  trim_silence true               # Enable silence trimming
  silence_threshold -60           # Silence threshold (dB)
  
  # Or use a custom audio filter string (FFmpeg format)
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,equalizer=f=150:width_type=h:width=100:g=-8,equalizer=f=300:width_type=h:width=100:g=2,equalizer=f=1200:width_type=h:width=600:g=3,equalizer=f=2500:width_type=h:width=1000:g=2,equalizer=f=5000:width_type=h:width=1000:g=1,afftdn=nf=-20:nr=0.5"
  
  # Output options
  output_format same              # Output format (same/mp3/aac/wav/ogg/flac)
  output_bitrate 192k             # Output bitrate
  output_sample_rate 44100        # Output sample rate
  output_channels 1               # Output channels
  
  buffer_path /tmp/fluentd-audio-transcoder  # Temporary file path
  tag transcoded.audio            # Output tag (default: "transcoded." + input tag)
</filter>
```

### Output Plugin Mode

```
<match audio.recording>
  @type audio_transcoder
  
  # Audio processing options
  audio_codec aac           # Audio codec (default: aac)
  audio_bitrate 192k        # Audio bitrate (default: 192k)
  audio_sample_rate 44100   # Audio sample rate (default: 44100)
  
  # Advanced audio filter settings
  audio_filter loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,equalizer=f=150:width_type=h:width=100:g=-8,equalizer=f=300:width_type=h:width=100:g=2,equalizer=f=1200:width_type=h:width=600:g=3,equalizer=f=2500:width_type=h:width=1000:g=2,equalizer=f=5000:width_type=h:width=1000:g=1,afftdn=nf=-20:nr=0.5
  
  # Output settings
  tag audio.normalized      # Tag for next stage (default: audio.normalized)
  remove_original false     # Remove original file after transcoding (default: false)
</match>
```

## Input Record Format

This plugin expects records with the following format:

```
{
  "path": "/path/to/recorded/audio/file.aac",
  "filename": "20240302-123456_1709289368_0.aac",
  "size": 123456,
  "device": 0,
  "format": "aac",
  "content": <binary data> // Audio data in the format specified by "format"
}
```

## Output Record Format

### Filter Plugin Mode

```
{
  "original_path": "/path/to/original/audio/file.aac",
  "original_filename": "20240302-123456_1709289368_0.aac",
  "original_size": 123456,
  "original_device": 0,
  "original_format": "aac",
  "path": "/path/to/processed/audio/file.mp3",
  "filename": "processed_20240302-123456_1709289368_0.mp3",
  "size": 98765,
  "format": "mp3",
  "processing": {
    "audio_filter": "volume=2.0,highpass=f=200",
    "audio_codec": "libmp3lame",
    "audio_bitrate": "192k",
    "audio_sample_rate": 44100,
    "audio_channels": 1
  },
  "content": <binary data> // Transcoded audio data
}
```

Note: Original fields are preserved with an "original_" prefix, but the original "content" field is excluded to reduce data size.

### Output Plugin Mode

```
{
  "path": "/path/to/normalized/audio/file.normalized.aac",
  "original_path": "/path/to/recorded/audio/file.aac",
  "size": 123456,
  "timestamp": 1709289368,
  "device": 0,
  "duration": 45.2,
  "format": "aac",
  "normalized": true
}
```

## Usage Examples

### Basic Audio Processing (Filter Mode)

```
<source>
  @type audio_recorder
  device 0
  tag audio.recording
</source>

<filter audio.recording>
  @type audio_transcoder
  audio_filter "volume=2.0,highpass=f=200,afftdn=nr=10:nf=-25"  # Volume amplification, highpass, noise reduction
  output_format aac
  output_bitrate 192k
  tag audio.processed
</filter>

<match audio.processed>
  @type file
  path /path/to/output
  format json
</match>
```

### Conference Recording Optimization (Filter Mode)

```
<filter audio.recording>
  @type audio_transcoder
  audio_filter "volume=1.5,bandpass=f=1000:width_type=h:width=800,afftdn=nr=12:nf=-30,silenceremove=1:0:-50dB"  # Bandpass, noise reduction, silence removal
  output_format mp3
  output_bitrate 128k
  output_sample_rate 44100
  tag audio.conference
</filter>
```

### Speech-to-Text Preparation (Filter Mode)

```
<filter audio.recording>
  @type audio_transcoder
  normalize true
  normalize_level -16
  noise_reduction true
  noise_reduction_level 0.3
  filter_type bandpass
  filter_frequency 1200
  trim_silence true
  silence_threshold -40
  output_format wav
  output_sample_rate 16000
  output_channels 1
  tag audio.for_stt
</filter>
```

### Processing as Output Plugin

```
<source>
  @type audio_recorder
  device 0
  tag audio.recording
</source>

<match audio.recording>
  @type audio_transcoder
  audio_filter "volume=2.0,highpass=f=200,afftdn=nr=10:nf=-25"
  audio_codec aac
  audio_bitrate 192k
  tag audio.normalized
</match>

<match audio.normalized>
  @type file
  path /path/to/output
  format json
</match>
```

## Audio Filters

This plugin applies the following filters by default:

- `loudnorm`: Volume normalization
- `highpass`/`lowpass`: Removal of unnecessary frequency bands
- `equalizer`: Audio clarification (multiple equalizers combined)
- `afftdn`: Noise reduction

These filters are optimized for speech transcription, especially for Japanese speech.

## Requirements

- Ruby 2.5.0 or later
- fluentd v1.0.0 or later
- streamio-ffmpeg
- ffmpeg (installed on the system)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Apache License, Version 2.0

# fluent-plugin-audio-transcoder

Fluentd用のオーディオトランスコードプラグイン。録音ファイルを正規化し、文字起こしに最適な形式に変換します。

## インストール

```
$ gem install fluent-plugin-audio-transcoder
```

## 設定

### フィルタープラグインモード

```
<filter audio.recording>
  @type audio_transcoder
  
  # 処理オプション（すべてオプション）
  normalize true                  # ボリュームノーマライズの有効/無効
  normalize_level -16             # ノーマライズのターゲットレベル（dB）
  
  noise_reduction true            # ノイズ除去の有効/無効
  noise_reduction_level 0.21      # ノイズ除去の強度（0.0～1.0）
  
  filter_type none                # フィルタータイプ（none/lowpass/highpass/bandpass）
  filter_frequency 1000           # フィルター周波数（Hz）
  
  trim_silence true               # 無音部分のトリミング
  silence_threshold -60           # 無音判定しきい値（dB）
  
  output_format same              # 出力フォーマット（same/mp3/aac/wav/ogg/flac）
  output_bitrate 192k             # 出力ビットレート
  output_sample_rate 44100        # 出力サンプルレート
  output_channels 1               # 出力チャンネル数
  
  buffer_path /tmp/fluentd-audio-transcoder  # 一時ファイルパス
  tag transcoded.audio            # 出力タグ（デフォルト: "transcoded." + 入力タグ）
</filter>
```

### 出力プラグインモード

```
<match audio.recording>
  @type audio_transcoder
  
  # オプションパラメータ
  audio_codec aac           # 音声コーデック（デフォルト: aac）
  audio_bitrate 192k        # 音声ビットレート（デフォルト: 192k）
  audio_sample_rate 44100   # 音声サンプルレート（デフォルト: 44100）
  
  # 高度な音声フィルター設定
  audio_filter loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,equalizer=f=150:width_type=h:width=100:g=-8,equalizer=f=300:width_type=h:width=100:g=2,equalizer=f=1200:width_type=h:width=600:g=3,equalizer=f=2500:width_type=h:width=1000:g=2,equalizer=f=5000:width_type=h:width=1000:g=1,afftdn=nf=-20:nr=0.5
  
  # 出力設定
  tag audio.normalized      # 次のステージへのタグ（デフォルト: audio.normalized）
  remove_original false     # トランスコード後に元のファイルを削除するか（デフォルト: false）
</match>
```

## 音声フィルターについて

このプラグインはデフォルトで以下のフィルターを適用します：

- `loudnorm`: 音量の正規化
- `highpass`/`lowpass`: 不要な周波数帯域の除去
- `equalizer`: 音声の明瞭化（複数のイコライザーを組み合わせ）
- `afftdn`: ノイズ除去

これらのフィルターは特に日本語の話し言葉の文字起こしに最適化されています。

## ライセンス

Apache License, Version 2.0
