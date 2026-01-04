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
end
