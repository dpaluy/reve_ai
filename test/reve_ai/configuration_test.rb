# frozen_string_literal: true

require "test_helper"

class ReveAI::ConfigurationTest < Minitest::Test
  def test_default_base_url
    config = ReveAI::Configuration.new
    assert_equal "https://api.reve.com", config.base_url
  end

  def test_default_timeout
    config = ReveAI::Configuration.new
    assert_equal 120, config.timeout
  end

  def test_default_open_timeout
    config = ReveAI::Configuration.new
    assert_equal 30, config.open_timeout
  end

  def test_default_max_retries
    config = ReveAI::Configuration.new
    assert_equal 2, config.max_retries
  end

  def test_api_key_defaults_from_env
    ENV["REVE_AI_API_KEY"] = "test_api_key_from_env"
    config = ReveAI::Configuration.new
    assert_equal "test_api_key_from_env", config.api_key
  ensure
    ENV.delete("REVE_AI_API_KEY")
  end

  def test_api_key_can_be_set
    config = ReveAI::Configuration.new
    config.api_key = "my_custom_key"
    assert_equal "my_custom_key", config.api_key
  end

  def test_valid_returns_true_when_api_key_present
    config = ReveAI::Configuration.new
    config.api_key = "some_key"
    assert config.valid?
  end

  def test_valid_returns_false_when_api_key_nil
    ENV.delete("REVE_AI_API_KEY")
    config = ReveAI::Configuration.new
    refute config.valid?
  end

  def test_valid_returns_false_when_api_key_empty
    config = ReveAI::Configuration.new
    config.api_key = ""
    refute config.valid?
  end

  def test_valid_aspect_ratios_constant
    expected = %w[16:9 9:16 3:2 2:3 4:3 3:4 1:1]
    assert_equal expected, ReveAI::Configuration::VALID_ASPECT_RATIOS
  end

  def test_max_prompt_length_constant
    assert_equal 2560, ReveAI::Configuration::MAX_PROMPT_LENGTH
  end

  def test_max_reference_images_constant
    assert_equal 6, ReveAI::Configuration::MAX_REFERENCE_IMAGES
  end
end
