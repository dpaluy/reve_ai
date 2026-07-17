# frozen_string_literal: true

require "test_helper"
require "json"

class ReveAI::HTTP::ClientTest < Minitest::Test
  def setup
    super
    @config = ReveAI::Configuration.new
    @config.api_key = "test_api_key"
    @http_client = ReveAI::HTTP::Client.new(@config)
  end

  def test_post_sends_request_with_correct_headers
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(
        headers: {
          "Authorization" => "Bearer test_api_key",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      )
      .to_return(status: 200, body: '{"image":"base64data"}', headers: { "Content-Type" => "application/json" })

    @http_client.post("/v1/image/create", {})
  end

  def test_post_sends_json_body
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(body: '{"prompt":"test"}')
      .to_return(status: 200, body: '{"image":"base64data"}', headers: {})

    @http_client.post("/v1/image/create", { prompt: "test" })
  end

  def test_post_returns_response_object_on_success
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 200,
        body: '{"image":"base64data","version":"reve-create@20250915","request_id":"rsid-123"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @http_client.post("/v1/image/create", {})

    assert_instance_of ReveAI::Response, response
    assert_equal 200, response.status
    assert_equal "base64data", response.body[:image]
  end

  def test_raises_bad_request_error_on_four_hundred
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 400,
        body: '{"error_code":"PROMPT_TOO_LONG","message":"Prompt exceeds maximum length"}',
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(ReveAI::BadRequestError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 400, error.status
    assert_equal "Prompt exceeds maximum length", error.message
  end

  def test_raises_unauthorized_error_on_four_hundred_one
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 401,
        body: '{"error_code":"INVALID_API_KEY","message":"Invalid API key"}',
        headers: {}
      )

    error = assert_raises(ReveAI::UnauthorizedError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 401, error.status
  end

  def test_raises_insufficient_credits_error_on_four_hundred_two
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 402,
        body: '{"error_code":"INSUFFICIENT_CREDITS","message":"Your budget has run out"}',
        headers: {}
      )

    error = assert_raises(ReveAI::InsufficientCreditsError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 402, error.status
  end

  def test_raises_unprocessable_entity_error_on_four_hundred_twenty_two
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 422,
        body: '{"error_code":"UNPROCESSABLE","message":"The inputs could not be understood"}',
        headers: {}
      )

    error = assert_raises(ReveAI::UnprocessableEntityError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 422, error.status
  end

  def test_raises_rate_limit_error_on_four_hundred_twenty_nine
    # Disable retries: the retry middleware honors Retry-After (60s) per attempt.
    @config.max_retries = 0
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 429,
        body: '{"error_code":"RATE_LIMIT","message":"Rate limit exceeded"}',
        headers: { "retry-after" => "60" }
      )

    error = assert_raises(ReveAI::RateLimitError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 429, error.status
    assert_equal 60, error.retry_after
  end

  def test_raises_server_error_on_five_hundred
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 500,
        body: '{"error_code":"INTERNAL_ERROR","message":"Internal server error"}',
        headers: {}
      )

    error = assert_raises(ReveAI::ServerError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal 500, error.status
  end

  def test_raises_timeout_error_on_timeout
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_timeout

    assert_raises(ReveAI::TimeoutError) do
      @http_client.post("/v1/image/create", {})
    end
  end

  def test_raises_connection_error_on_connection_failed
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    assert_raises(ReveAI::ConnectionError) do
      @http_client.post("/v1/image/create", {})
    end
  end

  def test_includes_user_agent_header
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(headers: { "User-Agent" => /reve-ai-ruby/ })
      .to_return(status: 200, body: '{"image":"data"}', headers: {})

    @http_client.post("/v1/image/create", {})
  end

  def test_get_sends_request_with_correct_headers
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .with(
        headers: {
          "Authorization" => "Bearer test_api_key",
          "Accept" => "application/json"
        }
      )
      .to_return(status: 200, body: '{"effects":[]}', headers: { "Content-Type" => "application/json" })

    response = @http_client.get("/v1/image/effect")

    assert_instance_of ReveAI::Response, response
    assert_equal [], response.body[:effects]
  end

  def test_get_merges_query_params_into_url
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .with(query: { source: "project" })
      .to_return(status: 200, body: '{"effects":[]}', headers: {})

    response = @http_client.get("/v1/image/effect", params: { source: "project" })

    assert response.success?
  end

  def test_get_raises_bad_request_error_on_four_hundred
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .to_return(
        status: 400,
        body: '{"error_code":"INVALID_SOURCE","message":"Invalid source filter"}',
        headers: {}
      )

    error = assert_raises(ReveAI::BadRequestError) do
      @http_client.get("/v1/image/effect")
    end

    assert_equal 400, error.status
    assert_equal "Invalid source filter", error.message
  end

  def test_get_raises_timeout_error_on_timeout
    stub_request(:get, "https://api.reve.com/v1/image/effect").to_timeout

    assert_raises(ReveAI::TimeoutError) do
      @http_client.get("/v1/image/effect")
    end
  end

  def test_get_raises_connection_error_on_connection_failed
    stub_request(:get, "https://api.reve.com/v1/image/effect")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    assert_raises(ReveAI::ConnectionError) do
      @http_client.get("/v1/image/effect")
    end
  end

  def test_post_merges_query_params_into_url
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(query: { breadcrumb: "checkout-step-2" })
      .to_return(status: 200, body: '{"image":"data"}', headers: {})

    response = @http_client.post("/v1/image/create", {}, params: { breadcrumb: "checkout-step-2" })

    assert response.success?
  end

  def test_post_with_per_request_accept_header
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(headers: { "Accept" => "image/webp" })
      .to_return(status: 200, body: '{"image":"data"}', headers: {})

    @http_client.post("/v1/image/create", {}, accept: "image/webp")
  end

  def test_post_accept_override_does_not_leak_into_connection_default
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(headers: { "Accept" => "image/webp" })
      .to_return(status: 200, body: "bytes", headers: { "Content-Type" => "image/webp" })
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .with(headers: { "Accept" => "application/json" })
      .to_return(status: 200, body: '{"image":"data"}', headers: { "Content-Type" => "application/json" })

    @http_client.post("/v1/image/create", {}, accept: "image/webp")
    response = @http_client.post("/v1/image/create", {})

    refute response.binary?
    assert_equal "data", response.body[:image]
  end

  def test_post_returns_raw_bytes_for_binary_image_response
    image_bytes = "\x89PNG\r\n\x1a\nfake".b
    stub_binary_image_success(image_bytes)

    response = @http_client.post("/v1/image/create", {}, accept: "image/webp")

    assert response.binary?
    assert_equal image_bytes, response.body.b
    assert_equal "rsid-binary-1", response.request_id
  end

  def test_binary_image_response_exposes_metadata_via_headers
    image_response = fetch_binary_image_response("\x89PNG\r\n\x1a\nfake".b)

    assert_equal "\x89PNG\r\n\x1a\nfake".b, image_response.image
    assert_equal "latest", image_response.version
    assert_equal 18, image_response.credits_used
    assert_equal 982, image_response.credits_remaining
    refute image_response.content_violation?
  end

  def test_raises_error_with_header_error_code_for_grey_image_error_response
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 400,
        body: "\x89PNG\r\n\x1a\ngrey".b,
        headers: {
          "Content-Type" => "image/png",
          "X-Reve-Error-Code" => "CONTENT_POLICY_VIOLATION",
          "X-Reve-Request-Id" => "rsid-grey-1"
        }
      )

    error = assert_raises(ReveAI::BadRequestError) do
      @http_client.post("/v1/image/create", {}, accept: "image/png")
    end

    assert_kind_of String, error.body
    assert_equal "CONTENT_POLICY_VIOLATION", error.error_code
    assert_equal "CONTENT_POLICY_VIOLATION", error.message
    assert_equal "rsid-grey-1", error.request_id
  end

  def test_error_exposes_params_from_json_error_body
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 400,
        body: '{"error_code":"INVALID_PARAMS","message":"Invalid parameters","params":{"aspect_ratio":"invalid"}}',
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(ReveAI::BadRequestError) do
      @http_client.post("/v1/image/create", {})
    end

    assert_equal "INVALID_PARAMS", error.error_code
    assert_equal({ aspect_ratio: "invalid" }, error.params)
  end

  private

  def stub_binary_image_success(image_bytes)
    stub_request(:post, "https://api.reve.com/v1/image/create")
      .to_return(
        status: 200,
        body: image_bytes,
        headers: {
          "Content-Type" => "image/webp",
          "X-Reve-Version" => "latest",
          "X-Reve-Credits-Used" => "18",
          "X-Reve-Credits-Remaining" => "982",
          "X-Reve-Request-Id" => "rsid-binary-1"
        }
      )
  end

  def fetch_binary_image_response(image_bytes)
    stub_binary_image_success(image_bytes)
    response = @http_client.post("/v1/image/create", {}, accept: "image/webp")
    ReveAI::ImageResponse.new(status: response.status, headers: response.headers, body: response.body)
  end
end
