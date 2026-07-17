# frozen_string_literal: true

require "test_helper"

class ReveAI::Resources::V2::LayoutsTest < Minitest::Test
  SAMPLE_LAYOUT = {
    prompt: "a person at a cafe",
    regions: [
      { label: "person", prompt: "a woman in a red coat",
        bbox: { x0: 0.1, y0: 0.1, x1: 0.6, y1: 0.9 } }
    ]
  }.freeze

  def setup
    super
    @client = ReveAI::Client.new(api_key: "test_key")
    @layouts = ReveAI::Resources::V2::Layouts.new(@client)
  end

  def test_inherits_from_base
    assert_kind_of ReveAI::Resources::Base, @layouts
  end

  # extract

  def test_extract_with_data_image
    stub_extract.with(body: { image: { data: "base64data" } }).to_return(extract_response)

    response = @layouts.extract(image: { data: "base64data" })

    assert_instance_of ReveAI::LayoutResponse, response
    assert_equal "A bottle of rosé wine on a terracotta surface", response.layout[:prompt]
    assert_equal 2, response.layout[:regions].length
    assert_equal "label 1", response.layout[:regions].last[:label]
    assert_equal "bottle 1", response.layout[:regions].last[:parent]
    assert_equal 80, response.credits_used
    assert_equal 920, response.credits_remaining
    refute response.content_violation?
  end

  def test_extract_with_ref_image_prompt_and_version
    stub_extract
      .with(body: hash_including(image: { ref: "id:123" }, prompt: "simplify", version: "latest"))
      .to_return(extract_response)

    response = @layouts.extract(image: { ref: "id:123" }, prompt: "simplify", version: "latest")

    assert response.success?
  end

  def test_extract_with_breadcrumb_sends_query_param
    stub_extract.with(query: { breadcrumb: "extract-step" }).to_return(extract_response)

    assert @layouts.extract(image: { data: "base64data" }, breadcrumb: "extract-step").success?
  end

  def test_extract_validates_image_shape
    assert_raises(ReveAI::ValidationError) { @layouts.extract(image: "base64data") }
    assert_raises(ReveAI::ValidationError) { @layouts.extract(image: { data: "x", ref: "y" }) }
    assert_raises(ReveAI::ValidationError) { @layouts.extract(image: { other: "x" }) }
    assert_raises(ReveAI::ValidationError) { @layouts.extract(image: { data: "" }) }
  end

  def test_extract_validates_prompt_length
    error = assert_raises(ReveAI::ValidationError) do
      @layouts.extract(image: { data: "base64data" }, prompt: "x" * 4001)
    end
    assert_match(/4000/, error.message)
  end

  # create

  def test_create_with_prompt_only
    stub_create_layout.with(body: { prompt: "a person at a cafe" }).to_return(create_layout_response)

    response = @layouts.create(prompt: "a person at a cafe")

    assert_instance_of ReveAI::LayoutResponse, response
    assert_equal "a person at a cafe", response.layout[:prompt]
    assert_equal "person", response.layout[:regions].first[:label]
  end

  def test_create_with_references_commands_and_aspect_ratio
    stub_create_layout
      .with(body: hash_including(
        references: [{ image: { data: "base64data" }, prompt: "the cafe scene" }],
        commands: [{ op: "add", label: "dog", at: { x: 0.5, y: 0.5 } }],
        aspect_ratio: "21:9"
      ))
      .to_return(create_layout_response)

    response = @layouts.create(
      references: [{ image: { data: "base64data" }, prompt: "the cafe scene" }],
      commands: [{ op: "add", label: "dog", at: { x: 0.5, y: 0.5 } }],
      aspect_ratio: "21:9"
    )

    assert response.success?
  end

  def test_create_requires_prompt_or_references
    error = assert_raises(ReveAI::ValidationError) { @layouts.create }
    assert_match(/at least one of prompt or references/i, error.message)
  end

  def test_create_validates_compound_references
    assert_raises(ReveAI::ValidationError) { @layouts.create(references: "base64data") }
    assert_raises(ReveAI::ValidationError) { @layouts.create(references: [{}]) }
    assert_raises(ReveAI::ValidationError) { @layouts.create(references: [{ image: "base64data" }]) }
    assert_raises(ReveAI::ValidationError) { @layouts.create(references: [{ layout: "not-a-hash" }]) }

    references = Array.new(9) { { prompt: "x" } }
    error = assert_raises(ReveAI::ValidationError) { @layouts.create(references: references) }
    assert_match(/Maximum 8 references/, error.message)
  end

  def test_create_accepts_layout_only_reference
    stub_create_layout.to_return(create_layout_response)

    response = @layouts.create(references: [{ layout: SAMPLE_LAYOUT }])

    assert response.success?
  end

  def test_create_rejects_empty_compound_reference_prompt
    error = assert_raises(ReveAI::ValidationError) do
      @layouts.create(references: [{ prompt: "" }])
    end

    assert_match(/prompt.*non-empty String/, error.message)
  end

  def test_create_rejects_non_string_compound_reference_prompt
    error = assert_raises(ReveAI::ValidationError) do
      @layouts.create(references: [{ prompt: 123 }])
    end

    assert_match(/prompt.*non-empty String/, error.message)
  end

  def test_create_validates_commands
    assert_raises(ReveAI::ValidationError) { @layouts.create(prompt: "x", commands: "add") }
    assert_raises(ReveAI::ValidationError) { @layouts.create(prompt: "x", commands: [{ label: "dog" }]) }
  end

  def test_create_validates_aspect_ratio
    assert_raises(ReveAI::ValidationError) { @layouts.create(prompt: "x", aspect_ratio: "5:3") }
  end

  # render

  def test_render_with_layout_only
    stub_render.with(body: hash_including(layout: hash_including(:regions))).to_return(render_response)

    response = @layouts.render(layout: SAMPLE_LAYOUT)

    assert_instance_of ReveAI::ImageResponse, response
    assert_equal "cmVuZGVyZWRfaW1hZ2U=", response.image
    assert_equal "a person at a cafe", response.layout[:prompt]
    assert_equal "latest", response.version
    assert_equal 150, response.credits_used
    assert_equal 770, response.credits_remaining
  end

  def test_render_with_all_options
    stub_render
      .with(body: hash_including(
        layout: hash_including(:regions),
        references: [{ image: { data: "base64data" } }],
        postprocessing: [{ process: "fit_image", max_dim: 2048 }],
        version: "latest"
      ))
      .to_return(render_response)

    response = @layouts.render(
      layout: SAMPLE_LAYOUT,
      references: [{ image: { data: "base64data" } }],
      postprocessing: [{ process: "fit_image", max_dim: 2048 }],
      version: "latest"
    )

    assert response.success?
  end

  def test_render_with_accept_image_webp_returns_binary
    image_bytes = "\x89PNG\r\n\x1a\nfake".b
    stub_render.to_return(
      status: 200,
      body: image_bytes,
      headers: { "Content-Type" => "image/webp", "X-Reve-Credits-Used" => "150" }
    )

    response = @layouts.render(layout: SAMPLE_LAYOUT, accept: "image/webp")

    assert response.binary?
    assert_equal image_bytes, response.image
    assert_equal 150, response.credits_used
    assert_nil response.layout
  end

  def test_render_validates_layout
    assert_raises(ReveAI::ValidationError) { @layouts.render(layout: nil) }
    assert_raises(ReveAI::ValidationError) { @layouts.render(layout: "not-a-hash") }
    assert_raises(ReveAI::ValidationError) { @layouts.render(layout: { prompt: "x" }) }
    assert_raises(ReveAI::ValidationError) { @layouts.render(layout: { regions: [] }) }
  end

  def test_render_accepts_string_keyed_layout
    stub_render.to_return(render_response)
    layout = { "regions" => [{ "label" => "person", "prompt" => "a woman", "bbox" => {} }] }

    assert @layouts.render(layout: layout).success?
  end

  def test_render_validates_postprocessing
    error = assert_raises(ReveAI::ValidationError) do
      @layouts.render(layout: SAMPLE_LAYOUT, postprocessing: [{ factor: 2 }])
    end
    assert_match(/'process' key/, error.message)
  end

  def test_render_raises_api_error_on_bad_request
    stub_render.to_return(
      status: 400,
      body: { error_code: "INVALID_LAYOUT", message: "regions are overlapping" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    error = assert_raises(ReveAI::BadRequestError) { @layouts.render(layout: SAMPLE_LAYOUT) }
    assert_equal "INVALID_LAYOUT", error.error_code
  end

  private

  def stub_extract
    stub_request(:post, "https://api.reve.com/v2/image/extract_layout")
  end

  def stub_create_layout
    stub_request(:post, "https://api.reve.com/v2/image/create_layout")
  end

  def stub_render
    stub_request(:post, "https://api.reve.com/v2/image/render_layout")
  end

  def extract_response
    json_response(fixture("v2_extract_layout_response.json"))
  end

  def create_layout_response
    json_response(fixture("v2_create_layout_response.json"))
  end

  def render_response
    json_response(fixture("v2_render_layout_response.json"))
  end

  def json_response(body)
    { status: 200, body: body, headers: { "Content-Type" => "application/json" } }
  end
end
