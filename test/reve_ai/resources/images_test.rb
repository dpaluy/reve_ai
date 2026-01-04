# frozen_string_literal: true

require "test_helper"

class ReveAI::Resources::ImagesTest < Minitest::Test
  def setup
    super
    @client = ReveAI::Client.new(api_key: "test_key")
    @images = @client.images
  end

  def test_inherits_from_base
    assert_kind_of ReveAI::Resources::Base, @images
  end

  # Create tests

  def test_create_with_prompt_only
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(body: hash_including(prompt: "A sunset"))
      .to_return(
        status: 200,
        body: fixture("create_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.create(prompt: "A sunset")

    assert_instance_of ReveAI::ImageResponse, response
    assert_equal "base64imagedata", response.image
  end

  def test_create_with_aspect_ratio
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(body: hash_including(prompt: "A sunset", aspect_ratio: "16:9"))
      .to_return(
        status: 200,
        body: fixture("create_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.create(prompt: "A sunset", aspect_ratio: "16:9")

    assert response.success?
  end

  def test_create_with_version
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(body: hash_including(prompt: "A sunset", version: "reve-create@20250915"))
      .to_return(
        status: 200,
        body: fixture("create_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.create(prompt: "A sunset", version: "reve-create@20250915")

    assert_equal "reve-create@20250915", response.version
  end

  def test_create_validates_prompt_required
    error = assert_raises(ReveAI::ValidationError) do
      @images.create(prompt: nil)
    end
    assert_match(/Prompt is required/, error.message)
  end

  def test_create_validates_prompt_not_empty
    error = assert_raises(ReveAI::ValidationError) do
      @images.create(prompt: "")
    end
    assert_match(/Prompt is required/, error.message)
  end

  def test_create_validates_prompt_max_length
    long_prompt = "a" * 2561
    error = assert_raises(ReveAI::ValidationError) do
      @images.create(prompt: long_prompt)
    end
    assert_match(/exceeds maximum length/, error.message)
  end

  def test_create_validates_aspect_ratio
    error = assert_raises(ReveAI::ValidationError) do
      @images.create(prompt: "A sunset", aspect_ratio: "5:4")
    end
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  # Edit tests

  def test_edit_with_required_params
    stub_request(:post, "https://api.reve.com/v1/image/edit")
      .with(body: hash_including(edit_instruction: "Add clouds", reference_image: "base64imagedata"))
      .to_return(
        status: 200,
        body: fixture("edit_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.edit(edit_instruction: "Add clouds", reference_image: "base64imagedata")

    assert_instance_of ReveAI::ImageResponse, response
    assert_equal "editedbase64data", response.image
  end

  def test_edit_with_aspect_ratio
    stub_request(:post, "https://api.reve.com/v1/image/edit")
      .with(body: hash_including(edit_instruction: "Add clouds", reference_image: "base64data", aspect_ratio: "16:9"))
      .to_return(
        status: 200,
        body: fixture("edit_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.edit(edit_instruction: "Add clouds", reference_image: "base64data", aspect_ratio: "16:9")

    assert response.success?
  end

  def test_edit_validates_edit_instruction_required
    error = assert_raises(ReveAI::ValidationError) do
      @images.edit(edit_instruction: nil, reference_image: "base64data")
    end
    assert_match(/Edit instruction is required/, error.message)
  end

  def test_edit_validates_reference_image_required
    error = assert_raises(ReveAI::ValidationError) do
      @images.edit(edit_instruction: "Add clouds", reference_image: nil)
    end
    assert_match(/Reference image is required/, error.message)
  end

  def test_edit_validates_reference_image_not_empty
    error = assert_raises(ReveAI::ValidationError) do
      @images.edit(edit_instruction: "Add clouds", reference_image: "")
    end
    assert_match(/Reference image is required/, error.message)
  end

  # Remix tests

  def test_remix_with_required_params
    stub_request(:post, "https://api.reve.com/v1/image/remix")
      .with(body: hash_including(
        prompt: "Combine these images",
        reference_images: %w[base64data1 base64data2]
      ))
      .to_return(
        status: 200,
        body: fixture("remix_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.remix(
      prompt: "Combine these images",
      reference_images: %w[base64data1 base64data2]
    )

    assert_instance_of ReveAI::ImageResponse, response
    assert_equal "remixedbase64data", response.image
  end

  def test_remix_with_aspect_ratio
    stub_request(:post, "https://api.reve.com/v1/image/remix")
      .with(body: hash_including(prompt: "Combine", reference_images: ["base64data"], aspect_ratio: "16:9"))
      .to_return(
        status: 200,
        body: fixture("remix_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.remix(
      prompt: "Combine",
      reference_images: ["base64data"],
      aspect_ratio: "16:9"
    )

    assert response.success?
  end

  def test_remix_with_img_tags_in_prompt
    stub_request(:post, "https://api.reve.com/v1/image/remix")
      .with(body: hash_including(prompt: "The person from <img>0</img> in the setting of <img>1</img>"))
      .to_return(
        status: 200,
        body: fixture("remix_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.remix(
      prompt: "The person from <img>0</img> in the setting of <img>1</img>",
      reference_images: %w[person_base64 setting_base64]
    )

    assert response.success?
  end

  def test_remix_validates_prompt_required
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: nil, reference_images: ["base64data"])
    end
    assert_match(/Prompt is required/, error.message)
  end

  def test_remix_validates_reference_images_required
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: "Combine", reference_images: nil)
    end
    assert_match(/Reference images are required/, error.message)
  end

  def test_remix_validates_reference_images_not_empty
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: "Combine", reference_images: [])
    end
    assert_match(/Reference images are required/, error.message)
  end

  def test_remix_validates_max_reference_images
    images = Array.new(7) { "base64data" }
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: "Combine", reference_images: images)
    end
    assert_match(/Maximum 6 reference images/, error.message)
  end

  def test_remix_validates_each_reference_image
    images = ["base64data", ""]
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: "Combine", reference_images: images)
    end
    assert_match(/Reference image at index 1 is empty/, error.message)
  end

  def test_remix_validates_aspect_ratio
    error = assert_raises(ReveAI::ValidationError) do
      @images.remix(prompt: "Combine", reference_images: ["base64data"], aspect_ratio: "5:4")
    end
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  # Error handling tests

  def test_handles_api_errors
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 401,
        body: { error_code: "INVALID_API_KEY", message: "Invalid API key" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(ReveAI::UnauthorizedError) do
      @images.create(prompt: "A sunset")
    end
    assert_equal 401, error.status
  end

  def test_handles_rate_limit_errors
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 429,
        body: { error_code: "RATE_LIMIT", message: "Rate limit exceeded" }.to_json,
        headers: { "Content-Type" => "application/json", "Retry-After" => "60" }
      )

    error = assert_raises(ReveAI::RateLimitError) do
      @images.create(prompt: "A sunset")
    end
    assert_equal 429, error.status
  end

  def test_handles_insufficient_credits_error
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 402,
        body: { error_code: "INSUFFICIENT_CREDITS", message: "Your budget has run out" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(ReveAI::InsufficientCreditsError) do
      @images.create(prompt: "A sunset")
    end
    assert_equal 402, error.status
  end

  def test_response_includes_credits_info
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 200,
        body: fixture("create_response.json"),
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.create(prompt: "A sunset")

    assert_equal 18, response.credits_used
    assert_equal 982, response.credits_remaining
  end

  def test_response_includes_content_violation_flag
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 200,
        body: { image: "", content_violation: true, request_id: "rsid-123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = @images.create(prompt: "A sunset")

    assert response.content_violation?
  end
end
