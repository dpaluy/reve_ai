# frozen_string_literal: true

require "test_helper"

class ReveAI::Resources::V2::ImagesTest < Minitest::Test
  def setup
    super
    @client = ReveAI::Client.new(api_key: "test_key")
    @images = ReveAI::Resources::V2::Images.new(@client)
  end

  def test_inherits_from_base
    assert_kind_of ReveAI::Resources::Base, @images
  end

  def test_create_with_prompt_only
    stub_create.with(body: { prompt: "A sunset" }).to_return(success_response)

    response = @images.create(prompt: "A sunset")

    assert_instance_of ReveAI::ImageResponse, response
    assert_equal "aGVsbG8gd29ybGQ=", response.image
    assert_equal "latest", response.version
    assert_equal 150, response.credits_used
    assert_equal 880, response.credits_remaining
    refute response.content_violation?
  end

  def test_create_returns_layout_from_json_response
    stub_create.to_return(success_response)

    response = @images.create(prompt: "A sunset")

    layout = response.layout
    assert_equal "A serene mountain landscape at sunset", layout[:prompt]
    assert_equal 2, layout[:regions].length
    assert_equal "mountain", layout[:regions].first[:label]
    assert_equal({ x0: 0.0, y0: 0.0, x1: 0.5, y1: 1.0 }, layout[:regions].first[:bbox])
  end

  def test_create_with_all_options_passed_through
    stub_create
      .with(body: hash_including(
        prompt: "Edit this",
        references: [{ data: "base64data" }],
        aspect_ratio: "4:1",
        postprocessing: [{ process: "fit_image", max_dim: 2048 }],
        test_time_scaling: 2,
        version: "reve-v2-create@260601"
      ))
      .to_return(success_response)

    response = @images.create(
      prompt: "Edit this",
      references: [{ data: "base64data" }],
      aspect_ratio: "4:1",
      postprocessing: [{ process: "fit_image", max_dim: 2048 }],
      test_time_scaling: 2,
      version: "reve-v2-create@260601"
    )

    assert response.success?
  end

  def test_create_with_ref_reference
    stub_create
      .with(body: hash_including(references: [{ ref: "id:3fa85f64-5717-4562-b3fc-2c963f66afa6" }]))
      .to_return(success_response)

    response = @images.create(
      prompt: "Extend <frame>0</frame>",
      references: [{ ref: "id:3fa85f64-5717-4562-b3fc-2c963f66afa6" }]
    )

    assert response.success?
  end

  def test_create_with_breadcrumb_sends_query_param
    stub_create.with(query: { breadcrumb: "v2-step-1" }).to_return(success_response)

    response = @images.create(prompt: "A sunset", breadcrumb: "v2-step-1")

    assert response.success?
  end

  def test_create_with_accept_image_webp_returns_binary
    image_bytes = "\x89PNG\r\n\x1a\nfake".b
    stub_create.to_return(
      status: 200,
      body: image_bytes,
      headers: {
        "Content-Type" => "image/webp",
        "X-Reve-Version" => "latest",
        "X-Reve-Credits-Used" => "150",
        "X-Reve-Request-Id" => "rsid-v2-binary-1"
      }
    )

    response = @images.create(prompt: "A sunset", accept: "image/webp")

    assert response.binary?
    assert_equal image_bytes, response.image
    assert_equal "latest", response.version
    assert_equal 150, response.credits_used
    assert_equal "rsid-v2-binary-1", response.request_id
    assert_nil response.layout
  end

  def test_create_accepts_v2_only_aspect_ratios
    %w[4:1 21:9 5:4 1:2 auto].each do |ratio|
      stub_create.with(body: hash_including(aspect_ratio: ratio)).to_return(success_response)

      assert @images.create(prompt: "A sunset", aspect_ratio: ratio).success?, "expected #{ratio} to be accepted"
    end
  end

  def test_create_validates_prompt_required
    assert_raises(ReveAI::ValidationError) { @images.create(prompt: "") }
    assert_raises(ReveAI::ValidationError) { @images.create(prompt: nil) }
  end

  def test_create_validates_prompt_max_length
    stub_create.to_return(success_response)
    assert @images.create(prompt: "x" * 4000).success?

    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "x" * 4001) }
    assert_match(/4000/, error.message)
  end

  def test_create_validates_aspect_ratio
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", aspect_ratio: "5:3") }
    assert_match(/Invalid aspect_ratio/, error.message)
  end

  def test_create_validates_references_type
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: "base64data") }
    assert_match(/must be an Array/, error.message)
  end

  def test_create_validates_references_max
    references = Array.new(9) { { data: "base64data" } }

    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: references) }
    assert_match(/Maximum 8 references/, error.message)
  end

  def test_create_accepts_eight_references
    stub_create.to_return(success_response)
    references = Array.new(8) { { data: "base64data" } }

    assert @images.create(prompt: "A sunset", references: references).success?
  end

  def test_create_validates_reference_entry_shape
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: ["base64data"]) }
    assert_match(/index 0 must be a Hash/, error.message)
  end

  def test_create_validates_reference_with_both_data_and_ref
    reference = { data: "base64data", ref: "id:123" }

    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: [reference]) }
    assert_match(/exactly one of 'data' or 'ref'/, error.message)
  end

  def test_create_validates_reference_with_neither_data_nor_ref
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: [{ image: "x" }]) }
    assert_match(/exactly one of 'data' or 'ref'/, error.message)
  end

  def test_create_validates_reference_data_not_empty
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", references: [{ data: "" }]) }
    assert_match(/'data' must be a non-empty String/, error.message)
  end

  def test_create_validates_postprocessing
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", postprocessing: "upscale") }
    assert_match(/Postprocessing must be an Array of Hashes/, error.message)
  end

  def test_create_validates_test_time_scaling
    error = assert_raises(ReveAI::ValidationError) { @images.create(prompt: "A sunset", test_time_scaling: 16) }
    assert_match(/test_time_scaling must be a number between 1 and 15/, error.message)
  end

  def test_create_raises_api_error_on_bad_request
    stub_create.to_return(
      status: 400,
      body: { error_code: "MISSING_REQUIRED_PARAMETER", message: "prompt is required" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    error = assert_raises(ReveAI::BadRequestError) { @images.create(prompt: "A sunset") }
    assert_equal "MISSING_REQUIRED_PARAMETER", error.error_code
  end

  private

  def stub_create
    stub_request(:post, "https://api.reve.com/v2/image/create")
  end

  def success_response
    {
      status: 200,
      body: fixture("v2_create_response.json"),
      headers: { "Content-Type" => "application/json" }
    }
  end
end
