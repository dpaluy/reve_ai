# frozen_string_literal: true

require "test_helper"

class ReveAI::ErrorsTest < Minitest::Test
  def test_error_inherits_from_standard_error
    assert ReveAI::Error < StandardError
  end

  def test_configuration_error_inherits_from_error
    assert ReveAI::ConfigurationError < ReveAI::Error
  end

  def test_validation_error_inherits_from_error
    assert ReveAI::ValidationError < ReveAI::Error
  end

  def test_api_error_inherits_from_error
    assert ReveAI::APIError < ReveAI::Error
  end

  def test_api_error_stores_status_body_and_headers
    error = ReveAI::APIError.new(
      "Something went wrong",
      status: 400,
      body: { error_code: "BAD_REQUEST" },
      headers: { "x-reve-request-id" => "rsid-abc123" }
    )

    assert_equal 400, error.status
    assert_equal({ error_code: "BAD_REQUEST" }, error.body)
    assert_equal({ "x-reve-request-id" => "rsid-abc123" }, error.headers)
    assert_equal "Something went wrong", error.message
  end

  def test_api_error_extracts_request_id_from_headers
    error = ReveAI::APIError.new(
      "Error",
      status: 500,
      headers: { "x-reve-request-id" => "rsid-xyz789" }
    )

    assert_equal "rsid-xyz789", error.request_id
  end

  def test_api_error_extracts_error_code_from_body
    error = ReveAI::APIError.new(
      "Error",
      status: 400,
      body: { error_code: "PROMPT_TOO_LONG" }
    )

    assert_equal "PROMPT_TOO_LONG", error.error_code
  end

  def test_unauthorized_error_inherits_from_api_error
    assert ReveAI::UnauthorizedError < ReveAI::APIError
  end

  def test_insufficient_credits_error_inherits_from_api_error
    assert ReveAI::InsufficientCreditsError < ReveAI::APIError
  end

  def test_unprocessable_entity_error_inherits_from_api_error
    assert ReveAI::UnprocessableEntityError < ReveAI::APIError
  end

  def test_rate_limit_error_inherits_from_api_error
    assert ReveAI::RateLimitError < ReveAI::APIError
  end

  def test_rate_limit_error_provides_retry_after
    error = ReveAI::RateLimitError.new(
      "Rate limited",
      status: 429,
      headers: { "retry-after" => "60" }
    )

    assert_equal 60, error.retry_after
  end

  def test_server_error_inherits_from_api_error
    assert ReveAI::ServerError < ReveAI::APIError
  end

  def test_bad_request_error_inherits_from_api_error
    assert ReveAI::BadRequestError < ReveAI::APIError
  end

  def test_not_found_error_inherits_from_api_error
    assert ReveAI::NotFoundError < ReveAI::APIError
  end

  def test_network_error_inherits_from_error
    assert ReveAI::NetworkError < ReveAI::Error
  end

  def test_timeout_error_inherits_from_network_error
    assert ReveAI::TimeoutError < ReveAI::NetworkError
  end

  def test_connection_error_inherits_from_network_error
    assert ReveAI::ConnectionError < ReveAI::NetworkError
  end
end
