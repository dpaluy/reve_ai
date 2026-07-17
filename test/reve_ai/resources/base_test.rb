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

  def test_get_delegates_to_http_client
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .with(query: { source: "preset" })
      .to_return(status: 200, body: '{"effects":[]}', headers: { "Content-Type" => "application/json" })

    response = @resource.send(:get, "/v1/image/effect", params: { source: "preset" })

    assert_instance_of ReveAI::Response, response
    assert_equal [], response.body[:effects]
  end

  def test_get_without_params_delegates_to_http_client
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .to_return(status: 200, body: '{"effects":[]}', headers: {})

    response = @resource.send(:get, "/v1/image/effect")

    assert response.success?
  end

  def test_post_passes_params_and_accept_to_http_client
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(query: { breadcrumb: "b-1" }, headers: { "Accept" => "image/webp" })
      .to_return(status: 200, body: "\x89PNG".b, headers: { "Content-Type" => "image/webp" })

    response = @resource.send(:post, "/v1/image/create", { prompt: "x" },
                              params: { breadcrumb: "b-1" }, accept: "image/webp")

    assert response.binary?
  end

  def test_post_without_options_still_works
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(headers: { "Accept" => "application/json" })
      .to_return(status: 200, body: '{"image":"data"}', headers: { "Content-Type" => "application/json" })

    response = @resource.send(:post, "/v1/image/create", { prompt: "x" })

    assert_equal "data", response.body[:image]
  end

  def test_validate_postprocessing_accepts_nil
    @resource.send(:validate_postprocessing!, nil)
  end

  def test_validate_postprocessing_accepts_valid_steps
    @resource.send(:validate_postprocessing!, [{ process: "upscale", upscale_factor: 2 }])
    @resource.send(:validate_postprocessing!, [{ "process" => "remove_background" }])
    @resource.send(:validate_postprocessing!, [])
  end

  def test_validate_postprocessing_raises_on_non_array
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_postprocessing!, "upscale")
    end
    assert_match(/must be an Array of Hashes/, error.message)
  end

  def test_validate_postprocessing_raises_on_non_hash_step
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_postprocessing!, ["upscale"])
    end
    assert_match(/must be an Array of Hashes/, error.message)
  end

  def test_validate_postprocessing_raises_when_process_key_missing
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_postprocessing!, [{ upscale_factor: 2 }])
    end
    assert_match(/step at index 0 must include a 'process' key/, error.message)
  end

  def test_validate_test_time_scaling_accepts_nil
    @resource.send(:validate_test_time_scaling!, nil)
  end

  def test_validate_test_time_scaling_accepts_valid_values
    @resource.send(:validate_test_time_scaling!, 1)
    @resource.send(:validate_test_time_scaling!, 15)
    @resource.send(:validate_test_time_scaling!, 7.5)
  end

  def test_validate_test_time_scaling_raises_on_non_numeric
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_test_time_scaling!, "high")
    end
    assert_match(/between 1 and 15/, error.message)
  end

  def test_validate_test_time_scaling_raises_out_of_range
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_test_time_scaling!, 16)
    end
    assert_match(/between 1 and 15/, error.message)

    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_test_time_scaling!, 0)
    end
    assert_match(/between 1 and 15/, error.message)
  end

  def test_validate_aspect_ratio_with_custom_list_accepts_v2_ratios
    @resource.send(:validate_aspect_ratio!, "21:9", ReveAI::Configuration::V2_ASPECT_RATIOS)
    @resource.send(:validate_aspect_ratio!, "auto", ReveAI::Configuration::V2_ASPECT_RATIOS)
  end

  def test_validate_aspect_ratio_default_list_rejects_v2_only_ratio
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_aspect_ratio!, "21:9")
    end
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  def test_validate_aspect_ratio_with_custom_list_rejects_unknown_ratio
    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_aspect_ratio!, "7:3", ReveAI::Configuration::V2_ASPECT_RATIOS)
    end
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  def test_validate_prompt_with_custom_max_length
    prompt = "a" * 3000

    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, prompt)
    end
    assert_match(/exceeds maximum length of 2560/, error.message)

    @resource.send(:validate_prompt!, prompt, max_length: ReveAI::Configuration::V2_MAX_PROMPT_LENGTH)
  end

  def test_validate_prompt_with_custom_max_length_rejects_too_long
    prompt = "a" * 4001

    error = assert_raises(ReveAI::ValidationError) do
      @resource.send(:validate_prompt!, prompt, max_length: ReveAI::Configuration::V2_MAX_PROMPT_LENGTH)
    end
    assert_match(/exceeds maximum length of 4000/, error.message)
  end
end
