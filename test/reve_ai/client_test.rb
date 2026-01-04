# frozen_string_literal: true

require "test_helper"

class ReveAI::ClientTest < Minitest::Test
  def test_initializes_with_api_key
    client = ReveAI::Client.new(api_key: "my_api_key")
    assert_equal "my_api_key", client.configuration.api_key
  end

  def test_raises_configuration_error_without_api_key
    ENV.delete("REVE_AI_API_KEY")

    error = assert_raises(ReveAI::ConfigurationError) do
      ReveAI::Client.new
    end

    assert_match(/API key is required/, error.message)
  end

  def test_uses_env_api_key_when_not_provided
    ENV["REVE_AI_API_KEY"] = "env_api_key"
    client = ReveAI::Client.new
    assert_equal "env_api_key", client.configuration.api_key
  ensure
    ENV.delete("REVE_AI_API_KEY")
  end

  def test_accepts_custom_options
    client = ReveAI::Client.new(api_key: "key", timeout: 60, max_retries: 5)

    assert_equal 60, client.configuration.timeout
    assert_equal 5, client.configuration.max_retries
  end

  def test_merges_with_global_config
    ReveAI.configure do |config|
      config.api_key = "global_key"
      config.timeout = 90
    end

    client = ReveAI::Client.new(api_key: "instance_key")

    assert_equal "instance_key", client.configuration.api_key
    assert_equal 90, client.configuration.timeout
  ensure
    ReveAI.reset_configuration!
  end

  def test_provides_images_accessor
    client = ReveAI::Client.new(api_key: "key")
    assert_instance_of ReveAI::Resources::Images, client.images
  end

  def test_images_returns_same_instance
    client = ReveAI::Client.new(api_key: "key")
    assert_same client.images, client.images
  end

  def test_provides_http_client_accessor
    client = ReveAI::Client.new(api_key: "key")
    assert_instance_of ReveAI::HTTP::Client, client.http_client
  end
end
