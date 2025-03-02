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
    
    # Create a real test audio file using FFmpeg
    @test_audio_file = File.join(@temp_dir, "test.wav")
    create_test_audio_file(@test_audio_file)
  end
  
  teardown do
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  CONFIG = %[
    buffer_path #{Dir.tmpdir}/fluent-plugin-audio-transcoder-test
    tag transcoded.test
  ]
  
  DEFAULT_TAG = "test.audio"
  
  # ヘルパーメソッド - 公式ドキュメントのfilterメソッドに相当
  def filter(config, messages, tag = DEFAULT_TAG)
    d = create_driver(config)
    d.run(default_tag: tag) do
      messages.each do |message|
        d.feed(message)
      end
    end
    d.filtered_records
  end
  
  sub_test_case "configuration" do
    test "default configuration" do
      d = create_driver(CONFIG)
      assert_nil d.instance.audio_filter
      assert_equal :same, d.instance.output_format
      assert_equal '192k', d.instance.output_bitrate
      assert_equal 44100, d.instance.output_sample_rate
      assert_equal 1, d.instance.output_channels
      assert_equal "transcoded.test", d.instance.tag
    end
    
    test "custom configuration" do
      custom_config = %[
        audio_filter "volume=2.0,afftdn=nr=10:nf=-25"
        output_format mp3
        output_bitrate 128k
        output_sample_rate 22050
        output_channels 2
        buffer_path /custom/path
        tag custom_tag
      ]
      
      d = create_driver(custom_config)
      assert_equal "volume=2.0,afftdn=nr=10:nf=-25", d.instance.audio_filter
      assert_equal :mp3, d.instance.output_format
      assert_equal '128k', d.instance.output_bitrate
      assert_equal 22050, d.instance.output_sample_rate
      assert_equal 2, d.instance.output_channels
      assert_equal "/custom/path", d.instance.buffer_path
      assert_equal "custom_tag", d.instance.tag
    end
  end
  
  sub_test_case "filter processing" do
    # Skip this test if FFmpeg is not available
    def setup_ffmpeg_skip
      begin
        FFMPEG.ffmpeg_binary
      rescue => e
        omit "FFmpeg is not available: #{e.message}"
      end
    end
    
    test "content should be different after transcoding" do
      setup_ffmpeg_skip
      
      # Get the hash of the original file
      original_content = File.binread(@test_audio_file)
      original_hash = Digest::SHA256.hexdigest(original_content)
      
      # Apply a simple audio filter that should change the content
      custom_config = CONFIG + %[
        audio_filter "volume=2.0"
        output_format mp3
      ]
      
      # Create test message
      message = {
        time: Time.now.to_i,
        record: {
          "path" => @test_audio_file,
          "filename" => "test.wav",
          "size" => File.size(@test_audio_file),
          "device" => 0,
          "format" => "wav",
          "content" => original_content
        }
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message[:record]])
      
      # Verify that the record was processed
      assert_equal 1, filtered_records.size
      
      # Get the processed content
      processed_record = filtered_records.first
      assert_not_nil processed_record, "Filtered record should not be nil"
      assert_kind_of Hash, processed_record, "Filtered record should be a Hash"
      processed_content = processed_record["content"]
      processed_hash = Digest::SHA256.hexdigest(processed_content)
      
      # Verify that the content has changed
      assert_not_equal original_hash, processed_hash, 
        "Transcoded content should be different from original content"
      
      # Log the content difference for debugging
      puts "Original content hash: #{original_hash}"
      puts "Processed content hash: #{processed_hash}"
      puts "Original file size: #{original_content.bytesize} bytes"
      puts "Processed file size: #{processed_content.bytesize} bytes"
    end
    
    test "basic audio processing" do
      setup_ffmpeg_skip
      
      custom_config = CONFIG + %[
        audio_filter "volume=2.0"
      ]
      
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "device" => 0,
        "format" => "wav",
        "content" => File.binread(@test_audio_file)
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message])
      
      # Verify we get a record back
      assert_equal 1, filtered_records.size
      
      record = filtered_records.first
      
      # Check that original fields are properly prefixed
      assert_equal @test_audio_file, record["original_path"]
      assert_equal "test.wav", record["original_filename"]
      assert_equal File.size(@test_audio_file), record["original_size"]
      assert_equal 0, record["original_device"]
      assert_equal "wav", record["original_format"]
      assert_not_nil record["path"]
      assert_equal "processed_test.wav", record["filename"]
      assert_equal "wav", record["format"]
      assert_not_nil record["size"]
      assert_not_nil record["content"]
      assert_not_nil record["processing"]
      assert_equal "volume=2.0", record["processing"]["audio_filter"]
    end
    
    test "with format conversion" do
      setup_ffmpeg_skip
      
      custom_config = CONFIG + %[
        audio_filter "volume=2.0"
        output_format mp3
      ]
      
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "format" => "wav",
        "content" => File.binread(@test_audio_file)
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message])
      
      # Verify we get a record back
      assert_equal 1, filtered_records.size
      
      record = filtered_records.first
      assert_equal "mp3", record["format"]
      assert_equal "processed_test.mp3", record["filename"]
    end
    
    test "with complex audio filter" do
      setup_ffmpeg_skip
      
      custom_config = CONFIG + %[
        audio_filter "volume=2.0,afftdn=nr=10:nf=-25,highpass=f=200"
      ]
      
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "format" => "wav",
        "content" => File.binread(@test_audio_file)
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message])
      
      # Verify we get a record back
      assert_equal 1, filtered_records.size
      
      record = filtered_records.first
      assert_equal "volume=2.0,afftdn=nr=10:nf=-25,highpass=f=200", record["processing"]["audio_filter"]
    end
    
    test "handling nonexistent files" do
      messages = [
        {
          "path" => "/nonexistent/path.wav",
          "filename" => "test.wav",
          "size" => 10000,
          "format" => "wav"
        }
      ]
      
      # Use the filter helper method
      filtered_records = filter(CONFIG, messages)
      
      # Should not return any records for non-existent files
      assert_equal 0, filtered_records.size
    end
    
    test "check tag handling" do
      setup_ffmpeg_skip
      
      custom_config = CONFIG + %[
        tag custom.transcoded.tag
      ]
      
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "format" => "wav",
        "content" => File.binread(@test_audio_file)
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message])
      
      # Verify we get a record back
      assert_equal 1, filtered_records.size
      
      # 設定したtagの値をテスト
      d = create_driver(custom_config)
      assert_equal "custom.transcoded.tag", d.instance.tag
    end
  end

  private

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscoderFilter).configure(conf)
  end
  
  def create_test_audio_file(path)
    # Create a simple test WAV file using FFmpeg
    # This creates a 1-second silence audio file
    begin
      command = "#{FFMPEG.ffmpeg_binary} -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -q:a 0 -y #{path} 2>/dev/null"
      system(command)
      
      unless File.exist?(path) && File.size(path) > 0
        raise "Failed to create test audio file at #{path}"
      end
    rescue => e
      puts "Error creating test audio file: #{e.message}"
      puts "Command was: #{command}"
      raise e
    end
  end
end
