require "helper"
require "fluent/plugin/out_audio_transcoder.rb"

class AudioTranscoderOutputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::AudioTranscoderOutput).configure(conf)
  end
end
