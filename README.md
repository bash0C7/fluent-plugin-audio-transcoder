# fluent-plugin-audio-transcoder

[Fluentd](https://fluentd.org/) filter plugin to transcode audio files using FFmpeg.

## Overview

This plugin transcodes audio binary content according to specified parameters and re-emits the processed content. It uses FFmpeg for audio transcoding, allowing for volume normalization and format conversion to optimize files for speech-to-text processing.

## Installation

### Requirements

- Ruby 3.4.1 or higher
- FFmpeg installed and accessible in the system path
- Fluentd v0.14.10 or higher

### RubyGems

```
$ gem install fluent-plugin-audio-transcoder
```

### Bundler

Add the following line to your Gemfile:

```ruby
gem 'fluent-plugin-audio-transcoder'
```

And then execute:

```
$ bundle
```

## Configuration

### Filter Configuration

```
<filter your.tag.here>
  @type audio_transcoder
  
  # FFmpeg transcoding options (optional)
  transcode_options -c:v copy -af loudnorm=I=-14:TP=0.0:print_format=summary
  
  # Output file extension (optional)
  output_extension aac
  
  # Path for temporary buffer files
  buffer_path /path/to/buffer/directory
</filter>
```

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| transcode_options | string | FFmpeg command-line options for transcoding including filters | -c:v copy -af loudnorm=I=-14:TP=0.0:print_format=summary |
| output_extension | string | File extension for the transcoded file | aac |
| buffer_path | string | Path for temporary files used during transcoding | /tmp/fluentd-audio-transcoder |

## Input/Output

### Input Record Fields

The plugin expects the following fields in the incoming record:

- **path**: Full path to the audio file (used for filename)
- **content**: Binary content of the audio file

### Output Record Fields

The plugin modifies the following fields in the output record:

- **path**: Full path to the transcoded audio file
- **content**: Binary content of the transcoded audio file
- **size**: Size of the transcoded audio file in bytes

Other fields in the record remain unchanged.

## Example

```
<filter audio.**>
  @type audio_transcoder
  transcode_options -c:v copy -af loudnorm=I=-16:TP=-1.5:print_format=summary
  output_extension mp3
  buffer_path /var/log/fluentd/audio_buffer
</filter>
```

This configuration will normalize the audio volume to -16 LUFS and convert it to MP3 format.

## Note

- The plugin creates temporary files in the specified buffer_path during processing. These files are not automatically deleted after processing and should be managed separately if needed.
- This plugin does not modify the tag of events as it follows the standard filter plugin behavior.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bash0C7/fluent-plugin-audio-transcoder.

## License

The gem is available as open source under the terms of the [Apache-2.0 License](https://opensource.org/licenses/Apache-2.0).
