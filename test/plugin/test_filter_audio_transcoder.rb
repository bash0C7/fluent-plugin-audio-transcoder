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
  ]
  
  DEFAULT_TAG = "test.audio"
  
  # Helper method
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
    test "custom configuration" do
      custom_config = %[
        transcode_options -ac aac -vn -af loudnorm=I=-15:TP=0.0:print_format=summary
        output_extension mp3
        buffer_path /custom/path
      ]
      
      d = create_driver(custom_config)
      assert_equal '-ac aac -vn -af loudnorm=I=-15:TP=0.0:print_format=summary', d.instance.transcode_options
      assert_equal 'mp3', d.instance.output_extension
      assert_equal "/custom/path", d.instance.buffer_path
    end
  end
  
  sub_test_case "filter processing" do
    test "content should be different after transcoding" do      
      # Get the hash of the original file
      original_content = File.binread(@test_audio_file)
      original_hash = Digest::SHA256.hexdigest(original_content)
      
      # Apply a simple audio filter that should change the content
      custom_config = CONFIG + %[
        transcode_options -c:v copy
        output_extension mp3
      ]
      
      # Create test message
      message = {
        "path" => @test_audio_file,
        "filename" => "test.wav",
        "size" => File.size(@test_audio_file),
        "device" => 0,
        "format" => "wav",
        "content" => original_content
      }
      
      # Use the filter helper method
      filtered_records = filter(custom_config, [message])
      
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
      
      # Verify output record format
      assert_equal "test.wav.mp3", File.basename(processed_record["path"])
      assert_not_nil processed_record["size"]
      assert_equal 0, processed_record["device"]
    end
    
    test "basic audio processing" do
      custom_config = CONFIG + %[
        transcode_options -c:v copy
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
      
      # Check the record has the correct structure
      assert_equal "test.wav.aac", File.basename(record["path"])
      assert_not_nil record["size"]
      assert_equal 0, record["device"]
      assert_not_nil record["content"]
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
