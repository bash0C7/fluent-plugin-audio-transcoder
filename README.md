# Configuration

## Filter Plugin Mode

```
<filter audio.recording>
  @type audio_transcoder
  
  # Audio filter string (FFmpeg format)
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,afftdn=nf=-20:nr=0.5,silenceremove=1:0:-60dB"
  
  # Transcode options (comma-separated key:value pairs)
  transcode_options audio_codec:aac,audio_bitrate:192k,audio_sample_rate:44100,audio_channels:1
  
  # Output file extension
  output_extension aac              # Output file extension (default: aac)
  
  buffer_path /tmp/fluentd-audio-transcoder  # Temporary file path
  tag transcoded.audio            # Output tag (default: "transcoded." + input tag)
</filter>
```

## Output Plugin Mode

```
<match audio.recording>
  @type audio_transcoder
  
  # Audio processing options
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,equalizer=f=150:width_type=h:width=100:g=-8,equalizer=f=300:width_type=h:width=100:g=2,equalizer=f=1200:width_type=h:width=600:g=3,equalizer=f=2500:width_type=h:width=1000:g=2,equalizer=f=5000:width_type=h:width=1000:g=1,afftdn=nf=-20:nr=0.5"
  
  # Transcode options
  transcode_options audio_codec:aac,audio_bitrate:192k,audio_sample_rate:44100,audio_channels:1
  
  # Output file extension
  output_extension aac
  
  # Output settings
  tag audio.normalized      # Tag for next stage (default: audio.normalized)
  remove_original false     # Remove original file after transcoding (default: false)
</match>
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
  "path": "/path/to/processed/audio/file.aac",
  "filename": "20240302-123456_1709289368_0aac.aac",
  "size": 98765,
  "format": "aac",
  "processing": {
    "audio_filter": "volume=2.0,highpass=f=200",
    "transcode_options": "audio_codec:aac,audio_bitrate:192k,audio_sample_rate:44100,audio_channels:1"
  },
  "content": <binary data> // Transcoded audio data
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
  transcode_options audio_codec:aac,audio_bitrate:192k
  output_extension aac
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
  transcode_options audio_codec:libmp3lame,audio_bitrate:128k,audio_sample_rate:44100
  output_extension mp3
  tag audio.conference
</filter>
```

### Speech-to-Text Preparation (Filter Mode)

```
<filter audio.recording>
  @type audio_transcoder
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=200,lowpass=f=3400,afftdn=nr=10:nf=-25,silenceremove=1:0:-40dB:2:0:-40dB"
  transcode_options audio_codec:pcm_s16le,audio_sample_rate:16000,audio_channels:1
  output_extension wav
  tag audio.for_stt
</filter>
```

# 日本語版更新部分

## 設定

### フィルタープラグインモード

```
<filter audio.recording>
  @type audio_transcoder
  
  # オーディオフィルター文字列（FFmpeg形式）
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,afftdn=nf=-20:nr=0.5,silenceremove=1:0:-60dB"
  
  # トランスコードオプション（カンマ区切りのkey:value形式）
  transcode_options audio_codec:aac,audio_bitrate:192k,audio_sample_rate:44100,audio_channels:1
  
  # 出力ファイル拡張子
  output_extension aac              # 出力ファイル拡張子（デフォルト: aac）
  
  buffer_path /tmp/fluentd-audio-transcoder  # 一時ファイルパス
  tag transcoded.audio            # 出力タグ（デフォルト: "transcoded." + 入力タグ）
</filter>
```

### 出力プラグインモード

```
<match audio.recording>
  @type audio_transcoder
  
  # 音声処理のオプション
  audio_filter "loudnorm=I=-16:TP=-1.5:LRA=11,highpass=f=60,lowpass=f=12000,equalizer=f=150:width_type=h:width=100:g=-8,equalizer=f=300:width_type=h:width=100:g=2,equalizer=f=1200:width_type=h:width=600:g=3,equalizer=f=2500:width_type=h:width=1000:g=2,equalizer=f=5000:width_type=h:width=1000:g=1,afftdn=nf=-20:nr=0.5"
  
  # トランスコードオプション
  transcode_options audio_codec:aac,audio_bitrate:192k,audio_sample_rate:44100,audio_channels:1
  
  # 出力ファイル拡張子
  output_extension aac
  
  # 出力設定
  tag audio.normalized      # 次のステージへのタグ（デフォルト: audio.normalized）
  remove_original false     # トランスコード後に元のファイルを削除するか（デフォルト: false）
</match>
```