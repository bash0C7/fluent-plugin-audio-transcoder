emitされた録音ファイルのバイナリーをconfで指定したパラメーターを使ってtranscodeして再emitするfluent filter pluginです。

# transcodeする
前のステップからの前提としている項目：
- path 録音ファイルのフルパス（ファイル名として使う）
- content 録音ファイルの内容のバイナリー

次のステップに渡すもの
- path transcode済み録音ファイルのフルパス
- content transcode済み録音ファイルの内容のバイナリー
- size 録音ファイルの内容のバイナリーのサイズ(バイト数)


# Configuration

- transcode_options: ffmpegに渡すtranscodeオプション(任意)
  - '-c:v copy -af loudnorm=I=-14:TP=0.0:print_format=summary' みたいなコマンドラインに渡す書き方
- output_extension(任意) 録音ファイルにつける拡張子
  - transcodeオプションの形式とあわせてください
- buffer_path
  - 実体のファイルを置いておく場所。バッファ扱い。この先の処理では使わないため適宜消すこと。

※一般的なfilterプラグインのためtagを操作する機能はない

# Rubyコード記述ルール

- コメントやメッセージは英語で統一
- READMEも英語で書く
- Ruby 2.4を使うRubyプログラマーの一般的な書き方にする
- buffer_pathや依存ライブラリなどはすでにあるものとしてチェックや自動生成の処理は行わない
