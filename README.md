# fluent-plugin-audio-transcoder

[Fluentd](https://fluentd.org/) output plugin to do something.

TODO: write description for you plugin.

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

You can generate configuration template:

```
$ fluent-plugin-config-format output audio-transcoder
```

You can copy and paste generated documents here.

## Copyright

* Copyright(c) 2025- bash0C7
* License
  * Apache License, Version 2.0

# fluent-plugin-audio-transcoder

Fluentd用のオーディオトランスコード出力プラグイン。録音ファイルを正規化し、文字起こしに最適な形式に変換します。

## インストール

```
$ gem install fluent-plugin-audio-transcoder
```

## 設定

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

## 入力レコード形式

```
{
  "path": "/path/to/recorded/audio/file.aac",
  "size": 123456,
  "timestamp": 1709289368,
  "device": 0,
  "duration": 45.2,
  "format": "aac"
}
```

## 出力レコード形式

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

## 必要条件

- Ruby 2.5.0以上
- fluentd v1.0.0以上
- streamio-ffmpeg
- ffmpeg（システムにインストールされていること）

## 音声フィルターについて

このプラグインはデフォルトで以下のフィルターを適用します：

- `loudnorm`: 音量の正規化
- `highpass`/`lowpass`: 不要な周波数帯域の除去
- `equalizer`: 音声の明瞭化（複数のイコライザーを組み合わせ）
- `afftdn`: ノイズ除去

これらのフィルターは特に日本語の話し言葉の文字起こしに最適化されています。

## ライセンス

MIT License