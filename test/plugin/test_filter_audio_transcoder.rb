require "helper"
require "fluent/plugin/filter_audio_transcoder.rb"
require "fileutils"
require "tempfile"
require "digest"
require "streamio-ffmpeg"

class AudioTranscoderFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
    
    # Create temporary directory for buffer files
    @temp_dir = File.join(Dir.tmpdir, "fluent-plugin-audio-transcoder-test-#{rand(10000)}")
    FileUtils.mkdir_p(@temp_dir)
    
    # Create a real test audio file
    @test_audio_file = File.join(@temp_dir, "test.wav")
    create_test_audio_file(@test_audio_file)
    
    # Store original content for later comparison
    @original_content = File.binread(@test_audio_file)
    @original_hash = Digest::SHA256.hexdigest(@original_content)
  end
  
  teardown do
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  DEFAULT_TAG = "test.audio"
  DEFAULT_CONFIG = %[
    buffer_path #{Dir.tmpdir}/fluent-plugin-audio-transcoder-test
  ]
  
  sub_test_case "configuration" do
    test "should override default parameters with custom configuration" do
      # Arrange
      custom_config = %[
        transcode_options -ac aac -vn -af loudnorm=I=-15:TP=0.0:print_format=summary
        output_extension mp3
        buffer_path /custom/path
      ]
      
      # Act
      d = Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscoderFilter).configure(custom_config)
      
      # Assert
      assert_equal '-ac aac -vn -af loudnorm=I=-15:TP=0.0:print_format=summary', d.instance.transcode_options
      assert_equal 'mp3', d.instance.output_extension
      assert_equal "/custom/path", d.instance.buffer_path
    end
  end
  
  sub_test_case "transcoding functionality" do
    test "should change content hash when transcoding to mp3" do
      # Arrange
      d = Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscoderFilter).configure(DEFAULT_CONFIG + %[
        transcode_options -c:v copy
        output_extension mp3
      ])

      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "device" => 0,
        "format" => "wav",
        "content" => @original_content
      }
      
      # Act
      d.run(default_tag: DEFAULT_TAG) do
        d.feed(message)
      end
      
      # Assert
      filtered_record = d.filtered_records.first
      assert_not_nil filtered_record, "Filtered record should not be nil"
      
      processed_content = filtered_record["content"]
      processed_hash = Digest::SHA256.hexdigest(processed_content)
      
      assert_not_equal @original_hash, processed_hash, 
        "Transcoded content should be different from original content"
    end
    
    test "should produce expected output file format and maintain message fields" do
      # Arrange
      d = Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscoderFilter).configure(DEFAULT_CONFIG + %[
        transcode_options -c:v copy
        output_extension aac
      ])
      
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "device" => 0,
        "format" => "wav",
        "content" => @original_content
      }
      
      # Act
      d.run(default_tag: DEFAULT_TAG) do
        d.feed(message)
      end
      
      # Assert
      filtered_record = d.filtered_records.first
      assert_not_nil filtered_record, "Filtered record should not be nil"
      
      # Check output file format
      assert_equal "test.wav.aac", File.basename(filtered_record["path"])
      
      # Check that original fields are maintained
      assert_not_nil filtered_record["size"]
      assert_equal 0, filtered_record["device"]
      assert_equal "wav", filtered_record["format"]
      assert_not_nil filtered_record["content"]
    end
  end

  private

  def create_test_audio_file(path)
    # Create a 1-second silence audio file
    command = "#{FFMPEG.ffmpeg_binary} -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -q:a 0 -y #{path} 2>/dev/null"
    system(command)
    
    unless File.exist?(path) && File.size(path) > 0
      raise "Failed to create test audio file at #{path}"
    end
  end
end
