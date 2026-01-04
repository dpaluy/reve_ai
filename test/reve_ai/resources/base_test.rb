# frozen_string_literal: true

require "test_helper"

class ReveAI::Resources::BaseTest < Minitest::Test
  def setup
    super
    @client = ReveAI::Client.new(api_key: "test_key")
    @resource = ReveAI::Resources::Base.new(@client)
  end

  def test_stores_client_reference
    assert_equal @client, @resource.client
  end

  def test_validate_prompt_raises_on_nil
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, nil)
    end
    assert_match(/Prompt is required/, error.message)
  end

  def test_validate_prompt_raises_on_empty
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, "")
    end
    assert_match(/Prompt is required/, error.message)
  end

  def test_validate_prompt_raises_on_too_long
    long_prompt = "a" * 2561
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, long_prompt)
    end
    assert_match(/exceeds maximum length/, error.message)
  end

  def test_validate_prompt_accepts_valid_prompt
    @resource.send(:validate_prompt!, "A beautiful sunset")
  end

  def test_validate_prompt_with_custom_field_name
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, nil, field_name: "Edit instruction")
    end
    assert_match(/Edit instruction is required/, error.message)
  end

  def test_validate_aspect_ratio_accepts_nil
    @resource.send(:validate_aspect_ratio!, nil)
  end

  def test_validate_aspect_ratio_accepts_valid_ratios
    ReveAI::Configuration::VALID_ASPECT_RATIOS.each do |ratio|
      @resource.send(:validate_aspect_ratio!, ratio)
    end
  end

  def test_validate_aspect_ratio_raises_on_invalid
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_aspect_ratio!, "5:4")
    end
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  def test_validate_reference_image_raises_on_nil
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_image!, nil)
    end
    assert_match(/Reference image is required/, error.message)
  end

  def test_validate_reference_image_raises_on_empty
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_image!, "")
    end
    assert_match(/Reference image is required/, error.message)
  end

  def test_validate_reference_image_accepts_valid_base64
    @resource.send(:validate_reference_image!, "base64encodeddata")
  end

  def test_validate_reference_images_raises_on_nil
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_images!, nil)
    end
    assert_match(/Reference images are required/, error.message)
  end

  def test_validate_reference_images_raises_on_empty
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_images!, [])
    end
    assert_match(/Reference images are required/, error.message)
  end

  def test_validate_reference_images_raises_on_too_many
    images = Array.new(7) { "base64data" }
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_images!, images)
    end
    assert_match(/Maximum 6 reference images/, error.message)
  end

  def test_validate_reference_images_raises_on_empty_image
    images = ["base64data", ""]
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_reference_images!, images)
    end
    assert_match(/Reference image at index 1 is empty/, error.message)
  end

  def test_validate_reference_images_accepts_valid_images
    images = %w[base64data1 base64data2]
    @resource.send(:validate_reference_images!, images)
  end
end
